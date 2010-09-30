#!perl
# Example 1. A very simple "Synchronous Request" pattern
# Here is a very simple usage.
# It is almost the same as "WebService::Simple" module.
use warnings;
use strict;
use lib '../lib';
use WebService::Async;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
);
my $ret = $wa->get( q => 'hello' ); # send get request
print $ret->get;

__END__
Expected results below.
---
{"responseData": {"translatedText":"ciao"}, "responseDetails": null, "responseStatus": 200}
---
