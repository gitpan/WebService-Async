use strict;
use warnings;
use Smart::Args;
use Test::More 'no_plan';
use Test::Deep;
use Test::TCP;
use Plack::Loader;
use WebService::Async;
use WebService::Async::Parser::JSON;
use WebService::Async::Parser::XMLSimple;

sub create_client {
    args my $class, my $response => 'Any',
      my $parser    => 'Object',
      my $test_name => 'Str';
    return sub {
        my $port = shift;
        my $wa   = WebService::Async->new(
            base_url        => "http://127.0.0.1:${port}",
            param           => {},
            response_parser => $parser,
        );
        my $ret = $wa->get;
        cmp_deeply $ret->get, $response, $test_name;
    };
}

sub create_server {
    my $response = shift;
    return sub {
        my $port   = shift;
        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );
        $server->run(
            sub {
                return [ 200, [ 'Content-Type' => 'text/plain' ], [$response] ];
            }
        );
    };
}

# JSON
test_tcp(
    client => __PACKAGE__->create_client(
        parser    => WebService::Async::Parser::JSON->new,
        response  => { key1 => 'value1', key2 => 'value2' },
        test_name => 'WebService::Async::Parser::JSON',
    ),
    server => create_server('{ "key1": "value1", "key2": "value2" }'),
);

# XML
test_tcp(
    client => __PACKAGE__->create_client(
        parser    => WebService::Async::Parser::XMLSimple->new,
        response  => { key1 => 'value1', key2 => 'value2' },
        test_name => 'WebService::Async::Parser::XMLSimple',
    ),
    server => create_server('<root><key1>value1</key1><key2>value2</key2></root>'),
);
