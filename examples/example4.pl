#!perl
# Example 4. Asyncronous Request with callback
use warnings;
use strict;
use WebService::Async;
use WebService::Async::Parser::JSON;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
    response_parser => WebService::Async::Parser::JSON->new,
    on_done         => sub {
        my ( $async, $keys, $result ) = @_;
        print "on_done =>"
          . " key(@{$keys}):"
          . " value($result->{responseData}->{translatedText})\n";
    },
    on_complete => sub {
        my ( $async, $result ) = @_;
        print "on_complete\n";
        for ( $result->keys ) {
            print "  key(@{$_}): value("
              . $result->get($_)->{responseData}->{translatedText} . ")\n";
        }
    },
);
$wa->add_get( id => 1, param => { q => 'apple' } );
$wa->add_get(
    id    => 2,
    param => { q => 'orange' },
    sub { print "on_done => override!\n" }
);
$wa->add_get(
    id    => 3,
    lang  => 'fr',
    param => { q => 'grape', langpair => 'en|fr' }
);

$wa->send_request;
# blockking here automatically and sending 3 asynchronous requests.

__END__
Expected results below.
---
on_done => key(id 3 lang fr): value(raisins)
on_done => override!
on_done => key(id 1): value(mela)
on_complete
  key(id 2): value(arancione)
  key(id 3 lang fr): value(raisins)
  key(id 1): value(mela)
---

