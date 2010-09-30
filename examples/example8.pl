#!perl
# Example 8. Caching with memcached
use warnings;
use strict;
use Cache::Memcached;
use WebService::Async;
use WebService::Async::Parser::JSON;
use WebService::Async::ResponseCache;

use FindBin qw($Bin);
use Log::Dispatch::Config;
use Log::Dispatch::Configurator::YAML;
my $configure =
  Log::Dispatch::Configurator::YAML->new("${Bin}/log_config.yaml");
Log::Dispatch::Config->configure($configure);
my $logger = Log::Dispatch::Config->instance;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => {
        v        => '1.0',
        langpair => 'en|fr',
    },
    auto_block      => 1,
    response_parser => WebService::Async::Parser::JSON->new,
    logger          => $logger,
);
$wa->response_cache(
    WebService::Async::ResponseCache->new(
        cache => Cache::Memcached->new( { servers => ['localhost:11211'] } )
    )
);
$wa->add_get(
    id    => 1,
    lang  => 'en',
    param => { q => 'apple' }
);
$wa->add_get(
    id    => 2,
    lang  => 'en',
    param => { q => 'banana' }
);
my $result = $wa->send_request();

__END__
Expected results below.

-- First time: setting caches.
[Wed Sep 29 10:23:25 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
[Wed Sep 29 10:23:25 2010] [info] Does not hit any caches: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
[Wed Sep 29 10:23:25 2010] [debug] Cache set at: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
[Wed Sep 29 10:23:27 2010] [debug] Cache set at: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111

-- Second time: retrieving from caches.
[Wed Sep 29 10:12:52 2010] [info] Cache hit: http://ajax.googleapis.com/ajax/services/language/translate?q=banana&v=1.0&langpair=en%7Cfr?q=banana&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111
[Wed Sep 29 10:12:52 2010] [info] Cache hit: http://ajax.googleapis.com/ajax/services/language/translate?q=apple&v=1.0&langpair=en%7Cfr?q=apple&v=1.0&langpair=en%7Cfr at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 111

