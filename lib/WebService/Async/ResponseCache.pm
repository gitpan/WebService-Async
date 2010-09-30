package WebService::Async::ResponseCache;
use Moose;
use MooseX::WithCache;

use constant DEFAULT_EXPIRES => (60 * 60 * 24 * 7);

has default_expires => (
    is      => 'rw',
    isa     => 'Int',
    default => DEFAULT_EXPIRES,
);

with 'MooseX::WithCache' => { backend => 'Cache::Memcached', };

__PACKAGE__->meta->make_immutable;
no Moose;
no MooseX::WithCache;

use Smart::Args;

sub get_response {
    args my $self, my $key => 'Str';
    return $self->cache_get($key);
}

sub set_response {
    args my $self, my $key => 'Str',
      my $value   => 'Str',
      my $expires => { isa => 'Int', optional => 1 };
    $self->cache_set( $key, $value, $expires || $self->default_expires );
}

1;

__END__

=head1 NAME

WebService::Async::ResponseCache - Caching with MooseX::WithCache. This is for internal use only.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
