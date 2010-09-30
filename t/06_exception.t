use strict;
use warnings;
use Test::More 'no_plan';
use Test::TCP;
use Plack::Loader;
use Try::Tiny;
use Test::Exception;
use WebService::Async;

sub server_200 {
    my $port   = shift;
    my $server = Plack::Loader->auto(
        port => $port,
        host => '127.0.0.1',
    );
    $server->run(
        sub {
            sleep 1;
            return [ 200, [ 'Content-Type' => 'text/plain' ], [] ];
        }
    );
}

sub server_404 {
    my $port   = shift;
    my $server = Plack::Loader->auto(
        port => $port,
        host => '127.0.0.1',
    );
    $server->run(
        sub {
            return [ 404, [ 'Content-Type' => 'text/plain' ], [] ];
        }
    );
}

test_tcp(
    client => sub {
        my $cv = AE::cv;
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            auto_block => 0,
            on_complete => sub { $cv->send; },
        );
        $wa->add_get( id => 1, param => { q => 'banana' } );

        # The requst key is duplicate.
        throws_ok { $wa->add_get( id => 1, param => { q => 'banana' } ) } 
            qr{^The[ ]requst[ ]key[ ]is[ ]duplicate[.]}xms, 'duplicate key';

        $wa->send_request;

        # Cannot change the 'auto_block' attribute while the request queue is processing.
        throws_ok { $wa->auto_block(1) }
            qr{^Cannot[ ]change[ ]the[ ]'auto_block'[ ]
                attribute[ ]while[ ]the[ ]request[ ]queue[ ]
                is[ ]processing[.]}xms, 'setting auto_block';

        # Cannnot send the another request while the request queue is processing.
        try {
            $wa->send_request;
        }
        catch {
            like $_, qr{^Cannot[ ]send[ ]the[ ]another[ ]request[ ]
                while[ ]the[ ]request[ ]queue[ ]
                is[ ]processing[.]}xms, 'sending request twice';
        };

        $cv->recv;
    },
    server => \&server_200,
);

test_tcp(
    client => sub {
        my $port = shift;
        my $wa = WebService::Async->new(
            base_url => "http://127.0.0.1:${port}",
            param    => {},
            max_retry_count => 0,
        );
        try {
            $wa->get();
        } catch {
            like $_, qr{
                ^HTTP[ ]connection[ ]error[ ]occurred[.][ ]
                The[ ]status[ ]code[ ]is[ ]'404'[.]
            }xms, '404 error';
        };
    },
    server => \&server_404,
);
