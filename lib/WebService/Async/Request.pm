package WebService::Async::Request;
use Moose;
use Moose::Util::TypeConstraints;
use Smart::Args;
use Encode qw(decode_utf8);
use Regexp::Common qw(URI);
use URI::Escape qw(uri_escape_utf8);
use Hash::MultiKey;

enum 'WebService::Async::Request::Method' => qw(GET POST);

subtype 'WebService::Async::Request::URI' => as 'Str' =>
  where { /$RE{URI}{HTTP}/ };

has keys => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    handles => {
        all_keys   => 'elements',
        count_keys => 'count',
        get_key    => 'get',
    },
);
has method  => ( is => 'rw', isa => 'WebService::Async::Request::Method' );
has url     => ( is => 'rw', isa => 'WebService::Async::Request::URI' );
has param   => ( is => 'rw', isa => 'Maybe[HashRef]' );
has body    => ( is => 'ro', isa => 'Str', writer => '_body' );
has on_done => ( is => 'rw', isa => 'Maybe[CodeRef]' );
has key_for_cache => ( is => 'rw', isa => 'Str' );

sub get_keys_as_hash {
    args my $self;
    my %hash = @{ $self->keys };
    return \%hash;
}

sub _merge_param {
    args my $self, my $base_param => 'HashRef',
      my $option_param => { isa => 'HashRef', optional => 1 };
    if ( defined $option_param ) {
        my %p = ( %{$base_param}, %{$option_param} );
        return \%p;
    }
    return $base_param;
}

sub finalize {
    args my $self, my $base_param => 'HashRef',
      my $option_param => { isa => 'HashRef', optional => 1 };
    my $mp = $self->_merge_param(
        base_param   => $base_param,
        option_param => $option_param
    );
    $self->param($mp);
    my $joined = join '&',
      map { "$_=" . uri_escape_utf8( decode_utf8( $mp->{$_} ) ) } keys %{$mp};
    if ( $self->method eq 'GET' ) {
        $self->url( $self->url . "?${joined}" );
        $self->key_for_cache( $self->url );
    }
    elsif ( $self->method eq 'POST' ) {
        $self->_body($joined);
        $self->key_for_cache( $self->url . "?${joined}" );
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
no Moose::Util::TypeConstraints;

1;

__END__

=head1 NAME

WebService::Async::Request - Request class for internal use only.

=head1 METHODS

=head2 new(%options)

Constructor.

=head2 keys

A unique id for the request.

=head2 method

GET or POST.

=head2 url

Request URL.

=head2 param

Request header parameters.

=head2 body

Request body parameters.

=head2 on_done

Code reference which invoked when the request is finished.

=head2 key_for_cache

Key using when response is cached.

=head2 get_keys_as_hash

The key is ArrayRef. This method convert it to HashRef.

=head2 finalize

Building URL, header, request body and caching key.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
