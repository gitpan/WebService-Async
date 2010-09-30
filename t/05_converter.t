use strict;
use warnings;
use Test::More 'no_plan';
use Test::TCP;
use Plack::Loader;
use WebService::Async;
use WebService::Async::Parser::JSON;
use WebService::Async::Converter::JSON;
use WebService::Async::Converter::XMLSimple;
use WebService::Async::Converter::Function;

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

# JSON → HashRef → JSON
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            response_parser => WebService::Async::Parser::JSON->new,
            on_done => sub {
                my $value = $_[2];
                ok $value eq '{"key2":"value2","key1":"value1"}'
                    || $value eq '{"key1":"value1","key2":"value2"}', 'convert to JSON';
            },
        );
        $wa->response_converter(WebService::Async::Converter::JSON->new);
        my $ret = $wa->get()->get;
        is ref $ret, 'HASH', 'value is a HashRef when the request is completed'
    },
    server => create_server('{ "key1": "value1", "key2": "value2" }'),
);

# JSON → HashRef → XML
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            response_parser => WebService::Async::Parser::JSON->new,
            on_done => sub {
                my $value = $_[2];
                like $value, qr{
                    ^
                    (
                        <result>
                        \s+<key1>value1</key1>\s+
                        \s+<key2>value2</key2>\s+
                        </result>
                    |
                        <result>
                        \s+<key2>value2</key2>\s+
                        \s+<key1>value1</key1>\s+
                        </result>
                    )
                    $
                }xms, 'convert to XML';
            },
        );
        $wa->response_converter(WebService::Async::Converter::XMLSimple->new);
        my $ret = $wa->get()->get;
        is ref $ret, 'HASH', 'value is a HashRef when the request is completed'
    },
    server => create_server('{ "key1": "value1", "key2": "value2" }'),
);

# JSON → HashRef → XML(with parameters)
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            response_parser => WebService::Async::Parser::JSON->new,
            on_done => sub {
                my $value = $_[2];
                chomp $value;
                ok $value eq '<root key1="value1" key2="value2" />'
                 || $value eq '<root key2="value2" key1="value1" />', 'Convert to XML with parameters';
            },
        );
        my $converter = WebService::Async::Converter::XMLSimple->new;
        $converter->param({RootName => 'root'});
        $wa->response_converter($converter);
        $wa->get;
    },
    server => create_server('{ "key1": "value1", "key2": "value2" }'),
);

# JSON → HashRef → Function
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            on_done => sub {
                my $value = $_[2];
                is $value, 'HELLO', 'convert with a custom function';
            },
        );
        my $converter = WebService::Async::Converter::Function->new(
            converter => sub {
                my $value = $_[2];
                return uc $value;
            },
        );
        $wa->response_converter($converter);
        $wa->get;
    },
    server => create_server('hello'),
);
