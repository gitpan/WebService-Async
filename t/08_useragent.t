use strict;
use warnings;
use Test::More 'no_plan';
use Test::TCP;
use Test::Deep;
use Plack::Loader;
use Plack::Request;
use WebService::Async;

sub server {
    my($agent, $test_name) = @_; 
    return sub {
        my $port   = shift;
        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );
        $server->run(
            sub {
                my $req = Plack::Request->new(shift);
                is $req->user_agent, $agent, $test_name;
                return [ 200, [ 'Content-Type' => 'text/plain' ], [] ];
            }
        );
    };
}

test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
        );
        $wa->get;
    },
    server => server('Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)', 'alias setting. default ie6'),
);

test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
        );
        $wa->user_agent('abc');
        $wa->get;
    },
    server => server('abc', 'customized agent. abc'),
);
