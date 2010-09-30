package WebService::Async::Role::Parser;
use Moose::Role;
requires qw(parse _build_parser);

has parser => (
    is => 'rw',
    lazy_build => 1,
);

no Moose::Role;
1;

__END__

=head1 NAME

WebService::Async::Role::Parser - Role class for parser.

=head1 METHODS

=head2 parse

Parses the response object. Your parser class must implement this method.

=head2 _build_parser

Builds the parser object. Your parser class must implement this method.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
