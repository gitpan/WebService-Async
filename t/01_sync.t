use strict;
use warnings;
use Smart::Args;
use Test::More 'no_plan';
use Test::Deep;
use Test::TCP;
use Plack::Loader;
use Plack::Request;
use UNIVERSAL qw(can);
use WebService::Async;

sub create_client {
    args my $class, my $method => 'Str',
      my $param     => 'HashRef',
      my $opt_param => 'Maybe[HashRef]',
      my $key       => 'Maybe[HashRef]',
      my $response  => 'Any';

    return sub {
        my $port = shift;
        my $wa   = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => $param,
        );

        my $do_request =
          $method eq 'GET'
          ? WebService::Async->can('get')
          : WebService::Async->can('post');

        my $ret;
        if ( defined $key ) {
            $ret = $do_request->( $wa, %{$key}, param => $opt_param );
        }
        else {
            $ret = $do_request->( $wa, %{$opt_param} );
        }
        is $ret->get, $response, "[${method}] return value";
    };
}

sub create_server {
    args my $class, my $method => 'Str',
      my $param    => 'HashRef',
      my $response => 'Any';

    return sub {
        my $port   = shift;
        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );
        $server->run(
            sub {
                my $req       = Plack::Request->new(shift);
                my $req_param = $req->parameters->as_hashref;
                is $req->method, $method, "[${method}] request method";
                cmp_deeply $req_param, $param, "[${method}] parameters";
                return [ 200, [ 'Content-Type' => 'text/plain' ], [$response] ];
            }
        );
    };
}

# GET
test_tcp(
    client => __PACKAGE__->create_client(
        method => 'GET',
        param  => { v => '1.0', langpair => 'en|it' },
        opt_param => { q => 'hello' },
        key       => undef,
        response  => 'aaa',
    ),
    server => __PACKAGE__->create_server(
        method   => 'GET',
        param    => { v => '1.0', langpair => 'en|it', q => 'hello' },
        response => 'aaa',
    ),
);

# POST
test_tcp(
    client => __PACKAGE__->create_client(
        method => 'POST',
        param  => { v => '1.0', langpair => 'en|it' },
        opt_param => { q => 'hello' },
        key       => undef,
        response  => 'aaa',
    ),
    server => __PACKAGE__->create_server(
        method   => 'POST',
        param    => { v => '1.0', langpair => 'en|it', q => 'hello' },
        response => 'aaa',
    ),
);
