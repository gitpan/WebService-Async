#!perl
# Example 9. Handling exceptions
# This is a list of the prohibited matter.
use warnings;
use strict;
use Try::Tiny;
use WebService::Async;

my $cv = AE::cv;
my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => {
        v        => '1.0',
        langpair => 'en|fr',
    },
    auto_block => 0,
);
$wa->add_get( q  => 'apple' );
$wa->add_get( id => 1, param => { q => 'banana' } );

# The requst key is duplicate.
try {
    $wa->add_get( id => 1, param => { q => 'banana' } );
}
catch {
    warn $_;
};
$wa->send_request;

# Cannot change the 'auto_block' attribute while the request queue is processing.
try {
    $wa->auto_block(1);
}
catch {
    warn $_;
};

# Cannnot send the another request while the request queue is processing.
try {
    $wa->send_request;
}
catch {
    warn $_;
};

# If the status code of the response header is /^2/.
# Throws "HTTP connection error occured. The status code is '%s'." exception.

__END__
Expected results below.

The requst key is duplicate. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 198
    WebService::Async::_add_request('WebService::Async=HASH(0xa086778)', 'GET', 'id', 1, 'param', 'HASH(0xa53db30)') called at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 76
    WebService::Async::add_get('WebService::Async=HASH(0xa086778)', 'id', 1, 'param', 'HASH(0xa53db30)') called at examples/example9.pl line 23
    main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
    eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
    Try::Tiny::try('CODE(0xa08ebd0)', 'Try::Tiny::Catch=REF(0xa4fce78)') called at examples/example9.pl line 27

Cannot change the 'auto_block' attribute while the request queue is processing. at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 43
    Class::MOP::Class:::before('WebService::Async=HASH(0xa086778)', 1) called at /opt/perl/lib/site_perl/5.10.0/i686-linux-thread-multi/Class/MOP/Method/Wrapped.pm line 47
    Class::MOP::Method::Wrapped::__ANON__('WebService::Async=HASH(0xa086778)', 1) called at /opt/perl/lib/site_perl/5.10.0/i686-linux-thread-multi/Class/MOP/Method/Wrapped.pm line 89
    WebService::Async::auto_block('WebService::Async=HASH(0xa086778)', 1) called at examples/example9.pl line 32
    main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
    eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
    Try::Tiny::try('CODE(0xa51a330)', 'Try::Tiny::Catch=REF(0xa53dab0)') called at examples/example9.pl line 36

Cannot send the another request while the request queue is processing. at /opt/perl/lib/site_perl/5.10.0/WebService/Async/Role/RequestProcessor.pm line 221
    WebService::Async::Role::RequestProcessor::_process_request_queue('WebService::Async=HASH(0xa086778)') called at /opt/perl/lib/site_perl/5.10.0/WebService/Async.pm line 93
    WebService::Async::send_request('WebService::Async=HASH(0xa086778)') called at examples/example9.pl line 40
    main::__ANON__() called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 76
    eval {...} called at /opt/perl/lib/site_perl/5.10.0/Try/Tiny.pm line 67
    Try::Tiny::try('CODE(0xa51a330)', 'Try::Tiny::Catch=REF(0xa51ae20)') called at examples/example9.pl line 44


