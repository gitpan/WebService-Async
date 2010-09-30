#!perl
# Example 5. Asyncronous Request without auto blockking
use warnings;
use strict;
use WebService::Async;
use WebService::Async::Parser::JSON;

my $cv = AE::cv;
my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
    response_parser => WebService::Async::Parser::JSON->new,
    on_complete     => \&on_complete,
    auto_block      => 0, # change manual block mode
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

__END__
Expected results below.
---
on_complete
  key(id 2): value(arancione)
  key(id 3): value(uva)
  key(id 1): value(mela)
---

