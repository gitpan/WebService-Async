use strict;
use warnings;
use Test::More 'no_plan';
use Test::Deep;
use Test::TCP;
use Plack::Loader;
use Plack::Request;
use WebService::Async;

sub create_async {
    return WebService::Async->new(
        base_url => "http://127.0.0.1:$_[0]",
        param    => {},
    );
}

sub create_server {
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

# [GET] Using the key automatically generated.
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = create_async($port);
        my $key1 = $wa->add_get(q => 'test1');
        my $key2 = $wa->add_get(q => 'test2');
        my $ret = $wa->send_request;
        is $ret->get($key1), 'TEST1', "[GET] automatically generated key 1";
        is $ret->get($key2), 'TEST2', "[GET] automatically generated key 2";
    },
    server => \&create_server,
);

# [POST] Using the key automatically generated.
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = create_async($port);
        my $key1 = $wa->add_post(q => 'test1');
        my $key2 = $wa->add_post(q => 'test2');
        my $ret = $wa->send_request;
        is $ret->get($key1), 'TEST1', "[POST] automatically generated key 1";
        is $ret->get($key2), 'TEST2', "[POST] automatically generated key 2";
    },
    server => \&create_server,
);

# [GET] Using your own specified key.
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = create_async($port);
        $wa->add_get(id => 1, param => {q => 'test1'});
        $wa->add_get(id => 2, param => {q => 'test2'});
        $wa->add_get(id1 => 3, id2 => 4, param => {q => 'abc'});
        my $ret = $wa->send_request;
        is $ret->get([id => 1]), 'TEST1', "[GET] a specified key with arrayref";
        is $ret->get({id => 2}), 'TEST2', "[GET] a specified key with hashref";
        is $ret->get([id1 => 3, id2 => 4]), 'ABC', "[GET] two specified keys with arrayref";
        is $ret->get([id2 => 4, id1 => 3]), undef, "[GET] two specified keys with arrayref(incorrect order)";
        is $ret->get({id1 => 3, id2 => 4}), 'ABC', "[GET] two specified keys with hashref";
        is $ret->get({id2 => 4, id1 => 3}), 'ABC', "[GET] two specified keys with hashref(incorrect order)";
    },
    server => \&create_server,
);

# [POST] Using your own specified key.
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = create_async($port);
        $wa->add_post(id => 1, param => {q => 'test1'});
        $wa->add_post(id => 2, param => {q => 'test2'});
        $wa->add_post(id1 => 3, id2 => 4, param => {q => 'abc'});
        my $ret = $wa->send_request;
        is $ret->get([id => 1]), 'TEST1', "[POST] a specified key with arrayref";
        is $ret->get({id => 2}), 'TEST2', "[POST] a specified key with hashref";
        is $ret->get([id1 => 3, id2 => 4]), 'ABC', "[POST] two specified keys with arrayref";
        is $ret->get([id2 => 4, id1 => 3]), undef, "[POST] two specified keys with arrayref(incorrect order)";
        is $ret->get({id1 => 3, id2 => 4}), 'ABC', "[POST] two specified keys with hashref";
        is $ret->get({id2 => 4, id1 => 3}), 'ABC', "[POST] two specified keys with hashref(incorrect order)";
    },
    server => \&create_server,
);

# [GET] callback style
test_tcp(
    client => sub {
        my $port = shift;
        my $wa = create_async($port);
        my $key1 = $wa->add_get(q => 'test1');
        my $key2 = $wa->add_get(q => 'test2');
        $wa->on_done(sub {
            my ($sv, $key, $ret) = @_;
            my $expected = $key eq $key1 ? 'TEST1' : $key eq $key2 ? 'TEST2' : '';
            is $ret, $expected, "[GET] automatically generated key with on_done callback";
        });
        $wa->on_complete(sub {
            my ($sv, $ret) = @_;
            is $ret->get($key1), 'TEST1', "[GET] automatically generated key with on_complete callback";
            is $ret->get($key2), 'TEST2', "[GET] automatically generated key with on_complete callback";
        });
        $wa->send_request;
    },
    server => \&create_server,
);
