use strict;
use warnings;
use Test::More 'no_plan';
use Test::TCP;
use Plack::Loader;
use Plack::Request;
use WebService::Async;

sub uc_server {
    my $port   = shift;
    my $server = Plack::Loader->auto(
        port => $port,
        host => '127.0.0.1',
    );
    $server->run(
        sub {
            my $req = Plack::Request->new(shift);
            my $param = $req->parameters;
            my $q = $param->get('q');
            # upper case
            return [ 200, [ 'Content-Type' => 'text/plain' ], [uc $q] ];
        }
    );
}

test_tcp(
    client => sub {
        my $port = shift;
        my ($key1, $key2);
        my $cv = AE::cv;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            auto_block => 0,
            on_complete => sub {
                my $ret = $_[1];
                is $ret->get($key1), 'TEST1', "[on_complete] automatically generated key 1";
                is $ret->get($key2), 'TEST2', "[on_complete] automatically generated key 2";
                $cv->send;
            },
        );
        $key1 = $wa->add_get(q => 'test1');
        $key2 = $wa->add_get(q => 'test2');
        my $ret = $wa->send_request;
        is ref $ret, '', '[GET] return value is undefined';
        $cv->recv;
    },
    server => \&uc_server,
);
