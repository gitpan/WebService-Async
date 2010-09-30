#!perl
# Example 3. Asynchronous Request
# You have to get or create the access-key which relates the response to the request.
use warnings;
use strict;
use WebService::Async;
use WebService::Async::Parser::JSON;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
    response_parser => WebService::Async::Parser::JSON->new,
);

# USING THE AUTOMATIC GENERATED KEY
my $apple_key  = $wa->add_get( q => 'apple' );
my $orange_key = $wa->add_get( q => 'orange' );
my $grape_key  = $wa->add_get( q => 'grape' );
my $ret = $wa->send_request;
# blockking here automatically and sending 3 asynchronous requests.
print $ret->get($orange_key)->{responseData}->{translatedText} . "\n";

# USING YOUR OWN SPECIFIED KEY
$wa->add_get(id => 1, param => { q => 'pear' });
$wa->add_get(id => 2, param => { q => 'banana'});
$wa->add_get(id => 3, lang => 'fr', param => { q => 'cherry', langpair => 'en|fr' });
$ret = $wa->send_request;
# blockking here automatically and sending 3 asynchronous requests.
print $ret->get([id => 3, lang => 'fr'])->{responseData}->{translatedText}. "\n";

__END__
Expected results below.
---
arancione
cerise
---

