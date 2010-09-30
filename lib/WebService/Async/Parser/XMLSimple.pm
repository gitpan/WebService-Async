package WebService::Async::Parser::XMLSimple;
use Moose;
with 'WebService::Async::Role::Parser';

has '+parser' => (
    isa => 'XML::Simple',
);

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;

sub _build_parser {
    args my $self;
    require XML::Simple;
    $self->parser( XML::Simple->new );
}

sub parse {
    args my $self, my $response_body => 'Str';
    return $self->parser->XMLin($response_body);
}

1;

__END__

=head1 NAME

WebService::Async::Parser::XMLSimple - XML parser class with XML::Simple.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
