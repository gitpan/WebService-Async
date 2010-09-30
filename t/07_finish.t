use strict;
use warnings;
use Test::More 'no_plan';
use Test::TCP;
use Test::Deep;
use Plack::Loader;
use WebService::Async;

sub server {
    my $port   = shift;
    my $server = Plack::Loader->auto(
        port => $port,
        host => '127.0.0.1',
    );
    $server->run(
        sub {
            return [ 200, [ 'Content-Type' => 'text/plain' ], ['Hello'] ];
        }
    );
}

test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            max_retry_count => 0,
        );
        $wa->add_get;
        $wa->add_get;
        $wa->add_get;
        $wa->send_request;
        cmp_deeply $wa->_all_parsed_responses->_result, {}, 'clear all parsed responses';
        is $wa->_is_busy, 0, 'clear busy flag';
    },
    server => \&server,
);
