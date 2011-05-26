package WebService::Async::Converter::Raw;
use Moose;
with 'WebService::Async::Role::Converter';

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;
use Clone;

sub _build_converter { }

sub convert {
    args my $self, my $parsed_response => 'Object|HashRef|ArrayRef|Str',
      my $request => 'WebService::Async::Request',
      my $async   => 'WebService::Async';
    return Clone::clone($parsed_response);
}

1;

__END__

=head1 NAME

WebService::Async::Converter::Raw - Default converter class which does nothing.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
