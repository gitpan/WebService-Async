#!perl
# Example 6. Asyncronous Request with logging
use warnings;
use strict;
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

__END__
Expected results below.
---
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
---

