package WebService::Async::Parser::JSON;
use Moose;
with 'WebService::Async::Role::Parser';

has '+parser' => (
    isa => 'JSON',
);

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;
use Try::Tiny;

sub _build_parser {
    args my $self;
    require JSON;
    $self->parser( JSON->new );
}

sub parse {
    args my $self, my $response_body => 'Str';
    return $self->parser->decode($response_body);
}

1;

__END__

=head1 NAME

WebService::Async::Parser::JSON - JSON parser class with JSON.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
