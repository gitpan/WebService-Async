package WebService::Async::Parser::Raw;
use Moose;
with 'WebService::Async::Role::Parser';

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;

sub _build_parser { }

sub parse {
    args my $self, my $response_body => 'Str';
    return $response_body;
}

1;

__END__

=head1 NAME

WebService::Async::Parser::Raw - Default parser class which does nothing.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
