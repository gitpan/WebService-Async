package WebService::Async::Role::Converter;
use Moose::Role;
requires qw(convert _build_converter);

has converter => (
    is => 'rw',
    lazy_build => 1,
);

no Moose::Role;
1;

__END__

=head1 NAME

WebService::Async::Role::Converter - Role class for converter.

=head1 METHODS

=head2 convert

Converts the parsed response object. Your converter class must implement this method.

=head2 _build_converter

Builds the converter object. Your converter class must implement this method.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
