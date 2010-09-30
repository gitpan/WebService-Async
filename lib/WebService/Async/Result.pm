package WebService::Async::Result;
use Moose;
use Smart::Args;
use Hash::MultiKey;

has result => (
    is       => 'bare',
    isa      => 'HashRef',
    builder  => '_build_result',
    accessor => '_result',
);

sub _build_result {
    args my $self;
    tie my %ret, 'Hash::MultiKey';
    $self->_result( \%ret );
}

sub _keys {
    args my $self, my $key => 'HashRef';
    my @keys = map { ( $_, $key->{$_} ) } sort keys %{$key};
    return \@keys;
}

sub keys {
    args my $self;
    return keys %{$self->_result};
}

sub keys_as_hash {
    args my $self;
    my @ret;
    for my $key ( CORE::keys %{$self->_result} ) {
        my %hash = @{$key};
        push @ret, \%hash;
    }
    return @ret;
}

sub set {
    args my $self, my $key => 'ArrayRef|HashRef',
      my $value => 'ArrayRef|HashRef|Str';
    my $keys = ref $key eq 'HASH' ? $self->_keys( key => $key ) : $key;
    $self->_result->{$keys} = $value;
}

sub get {
    my ($self, $key) = @_;
    if ( $self->count == 1 && !defined $key ) {
        return (values %{ $self->_result })[0];
    }
    if ( defined $key ) {
        my $keys;
        if (ref $key eq 'HASH') {
            $keys = $self->_keys( key => $key );
        }
        elsif (ref $key eq 'ARRAY') {
            $keys = $key;
        }
        else {
            $keys = [$key];
        }
        return $self->_result->{$keys};
    }
    else {
        return;
    }
}

sub count {
    args my $self;
    return scalar( CORE::keys %{ $self->_result } );
}

sub clear {
    args my $self;
    undef %{ $self->_result };
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=head1 NAME

WebService::Async::Result - A class which stored the converted response.

=head1 METHODS

=head2 get([Str|HashRef|Arrayref])

Get the converted response by using key.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
