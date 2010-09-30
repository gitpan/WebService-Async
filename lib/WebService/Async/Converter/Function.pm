package WebService::Async::Converter::Function;
use Moose;
with 'WebService::Async::Role::Converter';

has '+converter' => ( isa => 'CodeRef' );

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;

sub _build_converter {
    sub { }
}

sub convert {
    args my $self, my $parsed_response => 'Object|HashRef|ArrayRef|Str',
      my $request => 'WebService::Async::Request',
      my $async   => 'WebService::Async';
    return $self->converter->( $async, $request, $parsed_response );
}

1;

__END__

=head1 NAME

WebService::Async::Converter::Function - Custom converter class which uses your own code reference.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
