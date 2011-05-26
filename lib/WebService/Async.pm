package WebService::Async;
use Moose;
use Moose::Util::TypeConstraints;

use 5.008008;
our $VERSION = '0.04';

use constant MAX_MAX_PER_HOST        => 6;
use constant DEFAULT_MAX_PER_HOST    => 4;
use constant DEFAULT_TIMEOUT         => 10;
use constant DEFAULT_RETRY_INTERVAL  => 10;
use constant DEFAULT_MAX_RETRY_COUNT => 3;
use constant SUCCESS => 1;
use constant FAILURE => 0;

subtype 'WebService::Async::MaxPerHost' => as 'Int' =>
  where { $_ <= MAX_MAX_PER_HOST && $_ > 0 };

has base_url => (
    is  => 'rw',
    isa => 'Str',
);

has param => (
    is  => 'rw',
    isa => 'HashRef',
);

has data_uuid => (
    is         => 'bare',
    isa        => 'Data::UUID',
    lazy_build => 1,
    accessor   => '_data_uuid',
);

has auto_block => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has request_condvar => (
    is       => 'bare',
    isa      => 'AnyEvent::CondVar',
    accessor => '_request_condvar',
    builder  => '_build_request_condvar',
);

has response_cache => (
    is  => 'rw',
    isa => 'WebService::Async::ResponseCache',
);

has is_busy => (
    is       => 'bare',
    isa      => 'Bool',
    accessor => '_is_busy',
);

has max_per_host => (
    is  => 'rw',
    isa => 'WebService::Async::MaxPerHost',
    trigger =>
      sub { $AnyEvent::HTTP::MAX_PER_HOST = $_[1] || DEFAULT_MAX_PER_HOST; },
);

has timeout => (
    is      => 'rw',
    isa     => 'Int',
    default => DEFAULT_TIMEOUT,
);

has retry_interval => (
    is      => 'rw',
    isa     => 'Int',
    default => DEFAULT_RETRY_INTERVAL,
);

has max_retry_count => (
    is      => 'rw',
    isa     => 'Int',
    default => DEFAULT_MAX_RETRY_COUNT,
);

has request_queue => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[WebService::Async::Request]',
    accessor => '_request_queue',
    default  => sub { [] },
    handles  => {
        count_request => 'count',
        pop_request   => 'pop',
        push_request  => 'push',
        all_requests  => 'elements',
    },
);

has all_parsed_responses => (
    is       => 'bare',
    isa      => 'WebService::Async::Result',
    accessor => '_all_parsed_responses',
    builder  => '_build_all_parsed_responses',
    handles  => {
        '_set_all_parsed_response'    => 'set',
        '_get_all_parsed_response'    => 'get',
        '_clear_all_parsed_responses' => 'clear',
    },
);

has response_parser => (
    is      => 'rw',
    does    => 'WebService::Async::Role::Parser',
    builder => '_build_response_parser',
    handles => { parse_response => 'parse', },
);

has response_converter => (
    is      => 'rw',
    does    => 'WebService::Async::Role::Converter',
    builder => '_build_response_converter',
    handles => { convert_response => 'convert', },
);

has whole_response_converter => (
    is      => 'rw',
    does    => 'WebService::Async::Role::Converter',
    builder => '_build_response_converter',
    handles => { convert_whole_response => 'convert', },
);

has logger => (
    is  => 'rw',
    isa => 'Log::Dispatch::Config',
);

has on_done => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub { }
    },
);

has known_agents => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef',
    handles => { get_known_agent => 'get', },
    default => sub {
        +{
            'Windows IE 6' =>
              'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
            'Windows Mozilla' =>
'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6',
            'Mac Safari' =>
'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/85 (KHTML, like Gecko) Safari/85',
            'Mac Mozilla' =>
'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401',
            'Linux Mozilla' =>
              'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624',
            'Linux Konqueror' => 'Mozilla/5.0 (compatible; Konqueror/3; Linux)',
        };
    },
);

has user_agent => (
    is      => 'rw',
    isa     => 'Maybe[Str]',
    builder => '_build_user_agent',
);

has on_complete => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub { }
    },
);

has on_error => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub { }
    },
);

has on_critical_error => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub { }
    },
);

has check_error => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub {
        sub { }
    },
);

has critical_error_message => (
    is  => 'rw',
    isa => 'Str',
);

before auto_block => sub {
    my ( $self, @args ) = @_;
    if ( $self->_is_busy && @args > 0 ) {
        confess
q{Cannot change the 'auto_block' attribute while the request queue is processing.};
    }
};

around user_agent => sub {
    my ( $next, $self, @args ) = @_;
    return $self->$next unless @args;
    my $alias = $args[0];
    my $agent = $self->get_known_agent($alias);
    $agent = $agent ? $agent : $alias;
    return $self->$next($agent);
};

no Moose;
no Moose::Util::TypeConstraints;

use Class::MOP;
use Smart::Args;
use Carp;
use Encode qw(decode_utf8);
use Scalar::Util 'weaken';
use Hash::MultiKey;
use AnyEvent;
use AnyEvent::HTTP;
use Log::Dispatch::Config;
use WebService::Async::Result;
use WebService::Async::Request;
use WebService::Async::ResponseCache;

sub get {
    my ( $self, @args ) = @_;
    $self->info(q{Invoke 'get' method.});
    return $self->_do_request( 'GET', @args );
}

sub post {
    my ( $self, @args ) = @_;
    $self->info(q{Invoke 'post' method.});
    return $self->_do_request( 'POST', @args );
}

sub add_get {
    my ( $self, @args ) = @_;
    $self->info(q{Invoke 'add_get' method.});
    $self->_add_request( 'GET', @args );
}

sub add_post {
    my ( $self, @args ) = @_;
    $self->info(q{Invoke 'add_post' method.});
    $self->_add_request( 'POST', @args );
}

sub send_request {
    args my $self, my $block => { isa => 'Bool', optional => 1 };

    $self->info(q{Invoke 'send_request' method.});

    if ( defined $block && $block ) {
        $self->auto_block(1);
    }
    $self->_process_request_queue;
    if ( $self->auto_block ) {
        return $self->_request_condvar->recv;
    }
}

sub BUILD {
    my ( $self, @init_args ) = @_;

    # create all log methods.
    __PACKAGE__->meta->make_mutable;
    for my $sub_name (
        qw(debug info notice warning error critical alert emergency))
    {
        __PACKAGE__->meta->add_method(
            $sub_name,
            sub {
                my ( $_self, $message ) = @_;
                return if !defined $_self->logger;
                $_self->logger->log( level => $sub_name, message => $message );
            }
        );
    }
    __PACKAGE__->meta->make_immutable;
}

sub _build_all_parsed_responses {
    args my $self;
    $self->_all_parsed_responses( WebService::Async::Result->new );
}

sub _build_response_parser {
    args my $self;
    require WebService::Async::Parser::Raw;
    $self->response_parser( WebService::Async::Parser::Raw->new );
}

sub _build_response_converter {
    args my $self;
    require WebService::Async::Converter::Raw;
    $self->response_converter( WebService::Async::Converter::Raw->new );
}

sub _build_whole_response_converter {
    args my $self;
    require WebService::Async::Converter::Raw;
    $self->whole_response_converter( WebService::Async::Converter::Raw->new );
}

sub _build_user_agent {
    args my $self;
    $self->user_agent('Windows IE 6');
}

sub _convert {
    args my $self, my $request => 'WebService::Async::Request',
      my $parsed_response => 'Object|HashRef|ArrayRef|Str',
      my $is_whole        => { isa => 'Bool', optional => 1 };
    if ( defined $is_whole && $is_whole ) {
        return $self->whole_response_converter->convert(
            async           => $self,
            request         => $request,
            parsed_response => $parsed_response
        );
    }
    return $self->response_converter->convert(
        async           => $self,
        request         => $request,
        parsed_response => $parsed_response
    );
}

sub _clear {
    args my $self;
    $self->_is_busy(0);
    $self->_clear_all_parsed_responses;
}

sub _build_request_condvar {
    args my $self;
    $self->_request_condvar(AE::cv);
}

sub _build_data_uuid {
    args my $self;
    require Data::UUID;
    $self->_data_uuid( Data::UUID->new );
}

sub _do_request {
    my $self   = shift;
    my $method = shift;

    if ( $self->_is_busy ) {
        $self->error(
'Cannot send the another request while the request queue is processing.'
        );
        confess
'Cannot send the another request while the request queue is processing.';
    }

    # search callbacks
    my @cb = grep { ref $_ eq 'CODE' } @_;
    my $on_complete = shift @cb;

    # extract other parameters
    my @args = grep { ref $_ ne 'CODE' } @_;
    my %args = @args;

    if ( defined $on_complete ) {
        $self->on_complete($on_complete);
    }

    return $self->_request(
        keys   => [ $self->_data_uuid->to_string( $self->_data_uuid->create ) ],
        method => $method,
        on_complete => $self->on_complete,
        param       => \%args
    );
}

sub _add_request {
    my $self   = shift;
    my $method = shift;

    if ( $self->_is_busy ) {
        $self->error(
'Cannot send the another request while the request queue is processing.'
        );
        confess
'Cannot send the another request while the request queue is processing.';
    }

    # search callbacks
    my @cb = grep { ref $_ eq 'CODE' } @_;
    my $on_done = shift @cb;

    # extract other parameters
    my @args = grep { ref $_ ne 'CODE' } @_;
    my %args = @args;

    # param => {}
    my @keys;
    my $param;
    if ( exists $args{param} && ref $args{param} eq 'HASH' ) {
        $param = delete $args{param};
        @keys = map { ( $_, $args{$_} ) } sort keys %args;
    }
    else {
        $param = \%args;
    }
    if ( !@keys ) {
        @keys = ( $self->_data_uuid->to_string( $self->_data_uuid->create ) );
    }

  ALL_EXISTS_LOOP:
    for my $req ( $self->all_requests ) {
        next ALL_EXISTS_LOOP if @keys != $req->count_keys;
        for ( my $i = 0 ; $i < @keys ; $i++ ) {
            next ALL_EXISTS_LOOP if $keys[$i] ne $req->get_key($i);
        }
        $self->error('The requst key is duplicate.');
        confess 'The requst key is duplicate.';
    }

    # add request
    my $request = $self->_create_request(
        keys    => \@keys,
        method  => $method,
        param   => $param,
        on_done => $on_done
    );
    $self->debug('Push a request into the request queue.');
    $self->push_request($request);
    return \@keys;
}

sub _create_request {
    args my $self, my $method => 'Str',
      my $keys    => { isa => 'ArrayRef',       optional => 1 },
      my $param   => { isa => 'HashRef',        optional => 1 },
      my $on_done => { isa => 'Maybe[CodeRef]', optional => 1 };

    my $request = WebService::Async::Request->new(
        keys    => $keys,
        method  => $method,
        url     => $self->base_url,
        on_done => $on_done,
    );
    $request->finalize( base_param => $self->param, option_param => $param );
    return $request;
}

sub _request {
    args my $self, my $method => 'Str',
      my $keys        => 'ArrayRef',
      my $on_complete => 'CodeRef',
      my $param       => { isa => 'HashRef', optional => 1 };
    my @args = ( keys => $keys, method => $method );
    if ( defined $param ) {
        push @args, ( param => $param );
    }
    my $request = $self->_create_request(@args);
    $self->on_complete($on_complete);
    $self->debug('Push a request into the request queue.');
    $self->push_request($request);
    $self->_process_request_queue;
    if ( $self->auto_block ) {
        return $self->_request_condvar->recv;
    }
}

sub _process_request_queue {
    my $self = shift;

    $self->debug('Start processing request queue.');

    # replace cv
    $self->_request_condvar(AE::cv);

    # set some counters
    my $request_count = my $all_request_count = $self->count_request;
    my $critical_error_counter = 0;

    # check whether connecting or not
    if ( $self->_is_busy ) {
        $self->error(
'Cannot send the another request while the request queue is processing.'
        );
        confess
'Cannot send the another request while the request queue is processing.';
    }
    if ($request_count) {
        $self->debug('Set the busy flag is true.');
        $self->_is_busy(1);
    }

    # a checking routine for the each response.
    my $done = sub {
        my ( $self, $success, $kill_guards, $id, $response, $request,
            $response_header_status, $is_critical )
          = @_;

        if ($is_critical) {
            $critical_error_counter++;
        }

        # killing guards
        for my $guard ( @{$kill_guards} ) {
            undef $guard;
        }

        # fire the on_done or on_error event
        if ($success) {
            $self->info(
q{One request is successfully completed. Execute 'on_done' callback.}
            );
            if ( defined $request && defined $request->on_done ) {
                $request->on_done->( $self, $id, $response, $request );
            }
            else {
                $self->on_done->( $self, $id, $response, $request );
            }
        }
        else {
            $self->warning(q{Request failed. Excecute 'on_error' callback.});
            $self->on_error->( $self, $response_header_status, $is_critical );
        }

        # fire the on_critical_error or on_complete event
        $request_count--;
        if ( $request_count <= 0 ) {

            # all requests failed with critical error
            if ( $all_request_count == $critical_error_counter ) {

                # clear the busy state and stored responses.
                $self->debug(
'The request is canceled with a critical error. Clear the busy flag.'
                );
                $self->debug(
'The request is canceled with a critical error. Clear all parsed responses.'
                );
                $self->_clear;

                # raise the exception after execution of $done and on_error.
                $self->error(
"HTTP connection error occurred. The status code is '${response_header_status}'."
                );
                $self->on_critical_error->(
                    $self, $self->critical_error_message
                );
                $self->_request_condvar()
                  ->croak(
"HTTP connection error occurred. The status code is '${response_header_status}'."
                  );
                return;    # skip later process
            }

            # all request successed
            my $all_converted_responses = $self->_convert(
                request         => $request,
                parsed_response => $self->_all_parsed_responses,
                is_whole        => 1,
            );

            # clear the busy state and stored responses.
            $self->debug(
                'The request is successfully completed. Clear the busy flag.');
            $self->debug(
'The request is successfully completed. Clear all parsed responses.'
            );
            $self->_clear;

            # fire the complete event and sending a signal.
            $self->info(
q{All the request is successfully completed. Execute 'on_complete' callback.}
            );
            $self->on_complete->( $self, $all_converted_responses );
            if ( $self->auto_block ) {
                $self->_request_condvar->send($all_converted_responses);
            }
        }
    };

    # process all requests
    while ( my $request = $self->pop_request ) {
        $self->debug( 'Start processing request: ' . $request->key_for_cache );
        my $keys          = $request->keys;
        my $url           = $request->url;
        my $method        = $request->method;
        my $retry_counter = $self->max_retry_count;
        my $timer;

        # checking, parsing, converting a cache and firing some events
        my $cache;
        if ( $self->response_cache ) {
            $cache = $self->response_cache->get_response(
                key => $request->key_for_cache );
        }
        if ( defined $cache ) {
            $self->info( 'Cache hit: ' . $request->key_for_cache );
            $self->debug('Parse a response.');
            my $parsed_response =
              $self->parse_response( response_body => $cache );
            $self->debug(
                'Set a parsed response into the WebService::Async::Result');
            $self->_set_all_parsed_response(
                key   => $keys,
                value => $parsed_response
            );
            $self->debug('Convert a parsed response to the specified format.');
            my $converted_response = $self->_convert(
                request         => $request,
                parsed_response => $parsed_response,
            );
            $done->( $self, SUCCESS, [], $keys, $converted_response, $request );

            next;    # skip later process
        }

        # does not hit any caches.
        $self->info( 'Does not hit any caches: ' . $request->key_for_cache );

# connection routine (caching, parsing, converting a response and firing some events)
        my $send_request;
        $send_request = sub {
            my $guard;

            # connection handler
            my $on_body = sub {
                my ( $body, $header ) = @_;
                $self->debug(
                    'Receive a response from ' . $request->key_for_cache );
                $body = decode_utf8($body);

                # retry on error
                my $is_critical_error = $header->{Status} !~ m{^2}xms;
                my $is_error          = !defined $body
                  || $self->check_error->( $header, $body );
                if ( $is_error || $is_critical_error ) {
                    $self->warning(
                        "An error occurred. Status code=$header->{Status}");
                    undef $timer;
                    if ( $retry_counter-- <= 0 ) {

                        # firing events.
                        $done->(
                            $self, FAILURE,
                            [ $guard, $timer ], $keys,
                            undef,               $request,
                            $header->{'Status'}, $is_critical_error
                        );
                        return;
                    }
                    $timer ||= AE::timer $self->retry_interval, 0,
                      $send_request;
                    return;    # skip later process
                }

                # caching, parsing, converting a resopnse and firing events.
                if ( $self->response_cache ) {
                    $self->debug( 'Cache set at: ' . $request->key_for_cache );
                    $self->response_cache->set_response(
                        key   => $request->key_for_cache,
                        value => $body
                    );
                }
                $self->debug('Parse a response.');
                my $parsed_response =
                  $self->parse_response( response_body => $body );
                $self->debug('Set a parsed response into the internal store.');
                $self->_set_all_parsed_response(
                    key   => $keys,
                    value => $parsed_response
                );
                $self->debug(
                    'Convert a parsed response to the specified format.');
                my $converted_response = $self->_convert(
                    request         => $request,
                    parsed_response => $parsed_response,
                );

                # firing events
                $done->(
                    $self, SUCCESS, [ $guard, $timer ],
                    $keys, $converted_response, $request, $header->{'Status'}
                );
            };    # end of $on_body

            # send a request
            my $retry = $self->max_retry_count - $retry_counter;
            if ( $retry == 0 ) {
                $retry = '[first time]';
            }
            else {
                $retry = "[retry=${retry}]";
            }
            $self->debug(
"Invoking http_request method ${retry} (method=${method} url=${url})."
            );

            $guard ||= http_request $method, $url,
              headers => {
                Accept       => '*/*',
                'User-Agent' => $self->user_agent,
                (
                    $method eq 'POST'
                    ? ( 'Content-Type' => 'application/x-www-form-urlencoded' )
                    : ()
                ),
              },
              timeout   => $self->timeout,
              body      => $request->body,
              on_header => sub {
                my ($head) = @_;
                return 0 if ref $head ne 'HASH';
                return 1;
              },
              on_body => $on_body;
        };    # end of $send_request
        $send_request->();
        weaken $send_request;
    }
}
1;

__END__

=head1 NAME

WebService::Async - Non-blocking interface to web service APIs

=head1 SYNOPSIS

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
      on_done         => sub {
          my ($service, $id, $res, $req) = @_;
          print $req->param->{'q'} . " => ";
          print "$res->{responseData}->{translatedText}\n";
      },
  );
  $wa->add_get( q => 'apple' );
  $wa->add_get( q => 'orange' );
  $wa->add_get( q => 'banana', langpair => 'en|fr' );
  $wa->send_request;    # sending three requests in parallel.

  Results below.
    orange => arancione
    banana => la banane
    apple => mela

=head1 DESCRIPTION

WebService::Async is a non-blocking interface to web service APIs.

This is similar to WebService::Simple but this is a non-blocking one.

So this module helps "PSGI/Plack streaming" programming with Tatsumaki and Gearman.
See example 11.

=over

=item * Easy to use asynchronous request.

=item * Caching with memcached.

=item * Retrying automatically on error.

=item * Logging with Log::Dispatch::Config (starting connection, storing cache, cache hit, etc...)

=item * Flexibly customizable.

=back

=head1 EXAMPLES

Here is 11 simple examples.

=head2 Example 1. A very simple "Synchronous Request" pattern

Here is a very simple usage.

It is almost the same as "WebService::Simple" module.

=head3 SOURCE

  use WebService::Async;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
  );
  my $ret = $wa->get( q => 'hello' ); # send get request
  print $ret->get;
  
=head3 RESULTS

  {"responseData": {"translatedText":"ciao"}, "responseDetails": null, "responseStatus": 200}

=head2 Example 2. "Synchronous Request" with a response parser

It is almost the same as "WebService::Simple" module.

=head3 SOURCE

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
  );
  my $ret = $wa->get( q => 'hello' );    # send get request
  print $ret->get->{responseData}->{translatedText};

=head3 RESULTS

  ciao

=head2 Example 3. Asynchronous request

You have to get or create the access-key which relates the response to the request.

=head3 SOURCE

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
  );
  
  # USING THE AUTOMATIC GENERATED KEY
  my $apple_key  = $wa->add_get( q => 'apple' );
  my $orange_key = $wa->add_get( q => 'orange' );
  my $grape_key  = $wa->add_get( q => 'grape' );
  my $ret = $wa->send_request;
  # blocking here automatically and sending 3 asynchronous requests.
  print $ret->get($orange_key)->{responseData}->{translatedText} . "\n";
  
  # USING YOUR OWN SPECIFIED KEY
  $wa->add_get(id => 1, param => { q => 'pear' });
  $wa->add_get(id => 2, param => { q => 'banana'});
  $wa->add_get(id => 3, lang => 'fr', param => { q => 'cherry', langpair => 'en|fr' });
  $ret = $wa->send_request;
  # blocking here automatically and sending 3 asynchronous requests.
  print $ret->get([id => 3, lang => 'fr'])->{responseData}->{translatedText}. "\n";

=head3 RESULTS

  arancione
  cerise

=head2 Example 4. Asyncronous request with callback

You can get results in your own callback function.

=head3 SOURCE

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
      on_done         => sub {
          my ( $async, $keys, $result ) = @_;
          print "on_done =>"
            . " key(@{$keys}):"
            . " value($result->{responseData}->{translatedText})\n";
      },
      on_complete => sub {
          my ( $async, $result ) = @_;
          print "on_complete\n";
          for ( $result->keys ) {
              print "  key(@{$_}): value("
                . $result->get($_)->{responseData}->{translatedText} . ")\n";
          }
      },
  );
  $wa->add_get( id => 1, param => { q => 'apple' } );
  $wa->add_get(
      id    => 2,
      param => { q => 'orange' },
      sub { print "on_done => override!\n" }
  );
  $wa->add_get(
      id    => 3,
      lang  => 'fr',
      param => { q => 'grape', langpair => 'en|fr' }
  );
  
  $wa->send_request;
  # blocking here automatically and sending 3 asynchronous requests.

=head3 RESULTS

  on_done => key(id 3 lang fr): value(raisins)
  on_done => override!
  on_done => key(id 1): value(mela)
  on_complete
    key(id 2): value(arancione)
    key(id 3 lang fr): value(raisins)
    key(id 1): value(mela)

=head2 Example 5. Asyncronous Request without auto blocking

If you are familiar with AnyEvent, you can use non-blocking 'send_request';

This usage is useful when you want to access two or more sites at the same time.

=head3 SOURCE

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  my $cv = AE::cv;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
      on_complete     => \&on_complete,
      auto_block      => 0, # change block mode to manual
  );
  
  sub on_complete {
      my ( $async, $result ) = @_;
      print "on_complete\n";
      for my $key ( $result->keys ) {
          my $text = $result->get($key)->{responseData}->{translatedText};
          print "  key(@{${key}}): value(${text})\n";
      }
      $cv->send;
  }
  
  $wa->add_get( id => 1, param => { q => 'apple' } );
  $wa->add_get( id => 2, param => { q => 'orange' } );
  $wa->add_get( id => 3, param => { q => 'grape' } );
  $wa->send_request;
  $cv->recv;    # You have to block by your responsibility.

=head3 RESULTS

  on_complete
    key(id 2): value(arancione)
    key(id 3): value(uva)
    key(id 1): value(mela)

=head2 Example 6. Logging

If you want to using automatic logging, sets the Log::Dispatch instance to the logger attribute. 

=head3 SOURCE

  use WebService::Async;
  use WebService::Async::Parser::JSON;
  use FindBin qw($Bin);
  
  use Log::Dispatch::Config;
  use Log::Dispatch::Configurator::YAML;
  my $configure =
    Log::Dispatch::Configurator::YAML->new("${Bin}/log_config.yaml");
  Log::Dispatch::Config->configure($configure);
  my $logger = Log::Dispatch::Config->instance;
  
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
      on_complete     => \&on_complete,
      logger          => $logger,
  );
  
  sub on_complete {
      my ( $async, $result ) = @_;
      print "on_complete\n";
      for my $key ( $result->keys ) {
          my $text = $result->get($key)->{responseData}->{translatedText};
          print "  key(@{${key}}): value(${text})\n";
      }
  }
  
  $wa->add_get( id => 1, param => { q => 'apple' } );
  $wa->add_get( id => 2, param => { q => 'orange' } );
  $wa->add_get( id => 3, param => { q => 'grape' } );
  $wa->send_request;
  
=head3 RESULTS

  [Tue Sep 28 15:48:48 2010] [info] Invoke 'add_get' method. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Push a request into the request queue. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Invoke 'add_get' method. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Push a request into the request queue. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Invoke 'add_get' method. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Push a request into the request queue. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Invoke 'send_request' method. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Start processing request queue. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Set the busy flag is true. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Start processing request: http://ajax.googleapis.com/ajax/services/language/translate?q=grape&v=1.0&langpair=en%7Cit?q=grape&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=grape&v=1.0&langpair=en%7Cit?q=grape&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Start processing request: http://ajax.googleapis.com/ajax/services/language/translate?q=orange&v=1.0&langpair=en%7Cit?q=orange&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=orange&v=1.0&langpair=en%7Cit?q=orange&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Start processing request: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cit?q=apple&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cit?q=apple&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Invoking http_request method [first time] (method=GET url=http://ajax.googleapis.com/ajax/services/language/translate?q=grape&v=1.0&langpair=en%7Cit). at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Invoking http_request method [first time] (method=GET url=http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cit). at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:48 2010] [debug] Invoking http_request method [first time] (method=GET url=http://ajax.googleapis.com/ajax/services/language/translate?q=orange&v=1.0&langpair=en%7Cit). at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:49 2010] [debug] Receive a response from http://ajax.googleapis.com/ajax/services/language/translate?q=orange&v=1.0&langpair=en%7Cit?q=orange&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:49 2010] [debug] Parse a response. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:49 2010] [debug] Set a parsed response into the internal store. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:49 2010] [debug] Convert a parsed response to the specified format. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:49 2010] [info] One request is successfully completed. Execute 'on_done' callback. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Receive a response from http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cit?q=apple&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Parse a response. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Set a parsed response into the internal store. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Convert a parsed response to the specified format. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [info] One request is successfully completed. Execute 'on_done' callback. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Receive a response from http://ajax.googleapis.com/ajax/services/language/translate?q=grape&v=1.0&langpair=en%7Cit?q=grape&v=1.0&langpair=en%7Cit at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Parse a response. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Set a parsed response into the internal store. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] Convert a parsed response to the specified format. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [info] One request is successfully completed. Execute 'on_done' callback. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] The request is successfully completed. Clear the busy flag. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [debug] The request is successfully completed. Clear all parsed responses. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Tue Sep 28 15:48:51 2010] [info] All the request is successfully completed. Execute 'on_complete' callback. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  
  on_complete
    key(id 2): value(arancione)
    key(id 3): value(uva)
    key(id 1): value(mela)

=head2 Example 7. Asyncronous Request with response converter

You can customize the response by using a custom function or existing converter classes like WebService::Async::Converter::XMLSimple.

=head3 SOURCE

  use Text::MicroTemplate::DataSection 'render_mt';
  use WebService::Async;
  use WebService::Async::Parser::JSON;
  use WebService::Async::Converter::XMLSimple;
  use WebService::Async::Converter::Function;
  
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => { v => '1.0', langpair => 'en|it' },
      response_parser => WebService::Async::Parser::JSON->new,
      on_done         => sub {
          my ( $sv, $id, $result ) = @_;
          print "${result}\n";
      },
  );
  
  # It is useless because you can not relate the request to the response.
  # See the "Expected results below".
  $wa->response_converter( WebService::Async::Converter::XMLSimple->new );
  
  # You can customize the response by using a custom function.
  $wa->whole_response_converter(
      WebService::Async::Converter::Function->new( converter => \&_converter ) );
  sub _converter {
      my ( $sv, $request, $parsed_response ) = @_;
      my $converted_reponse =
        render_mt( 'whole_template', $parsed_response )->as_string;
      return $converted_reponse;
  }
  
  # translating
  $wa->add_get( id => 1, lang => 'fr', param => { q => 'apple', langpair => 'en|fr' } );
  $wa->add_get( id => 2, lang => 'it', param => { q => 'orange' } );
  $wa->add_get( id => 3, lang => 'it', param => { q => 'grape' } );
  my $result = $wa->send_request;
  print "${result}\n";
  
  __DATA__
  @@ whole_template
  <results>
  ? for my $key ($_[0]->keys_as_hash) {
  ?   my $text = $_[0]->get($key)->{responseData}->{translatedText};
      <translated id="<?= $key->{id} ?>" lang="<?= $key->{lang} ?>"><?= $text ?></translated>
  ? }
  </results>
  
=head3 RESULTS
  
  --- Output from on_done.
  --- It is useless because you can not relate the request to the response.
  <?xml version="1.0" encoding="UTF-8"?>
  <result>
    <responseData>
      <translatedText>mela</translatedText>
    </responseData>
    <responseDetails></responseDetails>
    <responseStatus>200</responseStatus>
  </result>
  
  <?xml version="1.0" encoding="UTF-8"?>
  <result>
    <responseData>
      <translatedText>uva</translatedText>
    </responseData>
    <responseDetails></responseDetails>
    <responseStatus>200</responseStatus>
  </result>
  
  <?xml version="1.0" encoding="UTF-8"?>
  <result>
    <responseData>
      <translatedText>arancione</translatedText>
    </responseData>
    <responseDetails></responseDetails>
    <responseStatus>200</responseStatus>
  </result>
  ---
  
  --- Output from send_request
  --- Relating the request to the resposne by using the key.
  <results>
      <translated id="3" lang="it">uva</translated>
      <translated id="1" lang="fr">Apple</translated>
      <translated id="2" lang="it">arancione</translated>
  </results>
  ---

=head2 Example 8. Caching with memcached

You can cache the responses by using Cache::Memcached.

The log is outputted when the cache stores or retrieves.

=head3 SOURCE

  use Cache::Memcached;
  use WebService::Async;
  use WebService::Async::Parser::JSON;
  use WebService::Async::ResponseCache;
  
  use FindBin qw($Bin);
  use Log::Dispatch::Config;
  use Log::Dispatch::Configurator::YAML;
  my $configure =
    Log::Dispatch::Configurator::YAML->new("${Bin}/log_config.yaml");
  Log::Dispatch::Config->configure($configure);
  my $logger = Log::Dispatch::Config->instance;
  
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => {
          v        => '1.0',
          langpair => 'en|fr',
      },
      auto_block      => 1,
      response_parser => WebService::Async::Parser::JSON->new,
      logger          => $logger,
  );
  $wa->response_cache(
      WebService::Async::ResponseCache->new(
          cache => Cache::Memcached->new( { servers => ['localhost:11211'] } )
      )
  );
  $wa->add_get(
      id    => 1,
      lang  => 'en',
      param => { q => 'apple' }
  );
  $wa->add_get(
      id    => 2,
      lang  => 'en',
      param => { q => 'banana' }
  );
  my $result = $wa->send_request();
  
=head3 RESULTS
  
  -- First time execution: setting caches.
  [Wed Sep 29 10:23:25 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Wed Sep 29 10:23:25 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Wed Sep 29 10:23:25 2010] [debug] Cache set at: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Wed Sep 29 10:23:27 2010] [debug] Cache set at: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  
  -- Second time execution: retrieving from caches.
  [Wed Sep 29 10:12:52 2010] [info] Cache hit: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
  [Wed Sep 29 10:12:52 2010] [info] Cache hit: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111

=head2 Example 9. Handling exceptions

This is a list of the prohibited matter.

=head3 SOURCE

  use Try::Tiny;
  use WebService::Async;
  my $cv = AE::cv;
  my $wa = WebService::Async->new(
      base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
      param    => {
          v        => '1.0',
          langpair => 'en|fr',
      },
      auto_block => 0,
  );
  $wa->add_get( q  => 'apple' );
  $wa->add_get( id => 1, param => { q => 'banana' } );
  
  # The requst key is duplicate.
  try {
      $wa->add_get( id => 1, param => { q => 'banana' } );
  }
  catch {
      warn $_;
  };
  $wa->send_request;
  
  # Cannot change the 'auto_block' attribute while the request queue is processing.
  try {
      $wa->auto_block(1);
  }
  catch {
      warn $_;
  };
  
  # Cannnot send the another request while the request queue is processing.
  try {
      $wa->send_request;
  }
  catch {
      warn $_;
  };
  
  # If the status code of the response header is /^2/,
  # throws "HTTP connection error occurred. The status code is '%s'." exception.
  
=head3 RESULTS
  
  The requst key is duplicate. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 198
      WebService::Async::_add_request('WebService::Async=HASH(0xa086778)', 'GET', 'id', 1, 'param', 'HASH(0xa53db30)') called at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 76
      WebService::Async::add_get('WebService::Async=HASH(0xa086778)', 'id', 1, 'param', 'HASH(0xa53db30)') called at examples/example9.pl line 23
      main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
      eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
      Try::Tiny::try('CODE(0xa08ebd0)', 'Try::Tiny::Catch=REF(0xa4fce78)') called at examples/example9.pl line 27
  
  Cannot change the 'auto_block' attribute while the request queue is processing. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 43
      Class::MOP::Class:::before('WebService::Async=HASH(0xa086778)', 1) called at /opt/perl/lib/site_perl/5.10.0/i686-linux-thread-multi/Class/MOP/Method/Wrapped.pm line 47
      Class::MOP::Method::Wrapped::__ANON__('WebService::Async=HASH(0xa086778)', 1) called at /opt/perl/lib/site_perl/5.10.0/i686-linux-thread-multi/Class/MOP/Method/Wrapped.pm line 89
      WebService::Async::auto_block('WebService::Async=HASH(0xa086778)', 1) called at examples/example9.pl line 32
      main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
      eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
      Try::Tiny::try('CODE(0xa51a330)', 'Try::Tiny::Catch=REF(0xa53dab0)') called at examples/example9.pl line 36
  
  Cannot send the another request while the request queue is processing. at /opt/perl/lib/site_perl/5.10.0/WebService/Async/Role/RequestProcessor.pm line 221
      WebService::Async::Role::RequestProcessor::_process_request_queue('WebService::Async=HASH(0xa086778)') called at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 93
      WebService::Async::send_request('WebService::Async=HASH(0xa086778)') called at examples/example9.pl line 40
      main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
      eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
      Try::Tiny::try('CODE(0xa51a330)', 'Try::Tiny::Catch=REF(0xa51ae20)') called at examples/example9.pl line 44


=head2 Example 10. Subclassing

See L<WebService::Async::Google::TranslateV1_0>

=head2 Example 11. Proxy Server for Google Translation Service.

This is a more complicated example using Plack, Tatsumaki and Subclassing(WebService::Async::Google::TranslateV1_0).

=head3 SOURCE

  package Translation;
  use Moose;
  extends 'Tatsumaki::Handler';
  
  use Tatsumaki::Application;
  use Encode qw(decode_utf8);
  use WebService::Async::Google::TranslateV1_0;
  
  __PACKAGE__->asynchronous(1);
  
  sub get {
      translate(@_);
  }
  
  sub post {
      translate(@_);
  }
  
  sub translate {
      my ( $self, $arg ) = shift;
      $self->response->content_type('text/xml');
      my $req    = $self->request;
      my $params = $req->parameters;
      my $src    = $params->get('f');
      $params->remove('f');
      my $dest = $params->get('t');
      $params->remove('t');
  
      if ( !defined $src || !defined $dest ) {
          # TODO throws an exception.
      }
      my @dest = split '\|', $dest;
      if ( !@dest ) {
          # TODO throws an exception.
      }
      my $service = WebService::Async::Google::TranslateV1_0->new;
      $service->source_language($src);
      $service->set_destination_languages(@dest);
      $params->each(
          sub {
              $service->set_message( decode_utf8( $_[0] ), $_[1] );
          }
      );
      $service->translate(
          on_each_translation => sub {
              my ( $sv, $id, $res ) = @_;
              $self->stream_write($res);
          },
          on_translation_complete => sub {
              my ( $atg, $all_res ) = @_;
              $self->stream_write($all_res);
              $self->finish;
          },
      );
  }
  
  my $app = Tatsumaki::Application->new( [
        '/translation/api/get' => 'Translation'
        ] );
  return $app;
  
=head1 METHODS

=head2 new(%opt)

Constructor. Create WebService::Async instance.

Available options are:

=over

=item base_url

Base url exclude query strings.

=item param

Query parameters. HashRef.

=item auto_block

1 or 0. Auto blocking or not.

=item max_per_host

Maximum per host. $AnyEvent::HTTP::MAX_PER_HOST.

=item timeout

Seconds.

=item retry_interval

Seconds.

=item max_retry_count

If given three, retrying three times on connection error.

=item response_parser

WebService::Async::Parser::* instance.

=item response_converter

WebService::Async::Converter::* instance.

=item whole_response_converter

WebService::Async::Converter::* instance.

=item logger

Log::Dispatch instance.

=item user_agent

User agent name or alias.
Alias can be 'Windows IE 6', 'Windows Mozilla', 'Mac Safari', 'Mac Mozilla', 'Linux Mozilla', 'Linux Konqueror'.

=item on_done

A code reference invoking when a request is done.

=item on_complete

A code reference invoking when all requests is completed.

=item on_error

A code reference invoking when the error occurs.

=item on_critical_error

A code reference invoking when the critical error occurs.

=item check_error

A code reference for checking  errors.

=item critical_error_message

This is a message that replaces the converted response when the critical error occurs.

See L<WebService::Async::Google::TranslateV1_0>

=back

=head2 get

Sending a get request and blocking.
Returns a converted response.
This method is synchronous use only.

=head2 post

Sending a post request and blocking.
Returns a converted response.
This method is synchronous use only.

=head2 add_get

Creating a get request and queuing it.
Returns a array reference which includes key for access the response.

=head2 add_post

Creating a post request and queuing it.
Returns a array reference which includes key for access the response.

=head2 send_request

Sending all queued requests and blocking;
Returns a converted response.

=head1 SUBCLASSING

For better encapsulation, you can create subclass of WebService::Async to customize the behavior.

See L<WebService::Async::Google::TranslateV1_0>.

=head1 PARSERS

If you want to use an existing parsers, see example 2.

Or if you want to create your own parsers such as a WebService::Async::Parser::MessagePack,
see L<WebService::Async::Parser::JSON>.

=head1 CACHING

See example 8.

=head1 DIAGNOSTICS

=over

=item Cannot send the another request while the request queue is processing.

Once you run 'send_request' method, you can not run another one until 'send_request' is finished.

=item The requst key is duplicate.

You must avoid to duplicating keys on using 'add_get' or 'add_post' method.

=item Cannot change the 'auto_block' attribute while the request queue is processing.

You can not change the 'auto_block' attribute while the request queue is processing.

=item HTTP connection error occurred. The status code is '%s'.

Throws If the status code of the response header is not /^2/.

=back

=head1 DEPENDENCIES

=over

=item L<AnyEvent>

=item L<AnyEvent::HTTP>

=item L<Clone>

=item L<Data::UUID>

=item L<Data::Section::Simple>

=item L<Encode>

=item L<Hash::MultiKey>

=item L<JSON>

=item L<Log::Dispatch::Config>

=item L<Moose>

=item L<MooseX::WithCache>

=item L<Regexp::Common>

=item L<Scalar::Util>

=item L<Smart::Args;>

=item L<Try::Tiny>

=item L<URI::Escape>

=item L<XML::Simple>

=item L<Plack::Loader>

=item L<Plack::Request>

=item L<Test::Deep>

=item L<Test::Exception>

=item L<Test::TCP>

=item L<Text::MicroTemplate>

=item L<Text::MicroTemplate::DataSection>

=item L<UNIVERSAL>

=back

=head1 POD BUGS

This POD does'nt make sense because my English Sux.

The best way to understand the usage of this module is reading the "SYNOPSIS" and "EXAMPLES" section.

=head1 GIT REPOSITORY

http://github.com/keroyonn/p5-WebService-Async

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 SEE ALSO

=over

=item L<WebService::Simple>

=item L<Tatsumaki>

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
