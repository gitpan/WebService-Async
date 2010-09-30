#!perl
# Example 2. "Synchronous Request" with a response parser
use warnings;
use strict;
use WebService::Async;
use WebService::Async::Parser::JSON;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
    response_parser => WebService::Async::Parser::JSON->new,
);
my $ret = $wa->get( q => 'hello' );    # send get request
print $ret->get->{responseData}->{translatedText};

__END__
Expected results below.
---
ciao
---

