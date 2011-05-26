package WebService::Async::Converter::XMLSimple;
use Moose;
with 'WebService::Async::Role::Converter';

has '+converter' => (
    isa => 'XML::Simple',
);

has param => (
    is => 'rw',
    isa => 'HashRef',
    default => sub {
        return +{
            RootName => 'result',
            NoAttr => 1,
            XMLDecl  => q{<?xml version="1.0" encoding="UTF-8"?>},
        };
    },
);

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;

sub _build_converter {
    args my $self;
    require XML::Simple;
    $self->converter(XML::Simple->new);
}

sub convert {
    args my $self, my $parsed_response => 'HashRef|ArrayRef',
      my $request => 'WebService::Async::Request',
      my $async   => 'WebService::Async';
    my @args = %{$self->param};
    return $self->converter->XMLout($parsed_response, @args);
}

1;

__END__

=head1 NAME

WebService::Async::Converter::XMLSimple - XML converter class with XML::Simple.

=head1 METHODS

=head2 param(HashRef)

Sets the HashRef to XMLout method.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
