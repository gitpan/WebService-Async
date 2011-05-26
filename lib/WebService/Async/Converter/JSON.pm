package WebService::Async::Converter::JSON;
use Moose;
with 'WebService::Async::Role::Converter';

has '+converter' => (
    isa => 'JSON',
);

__PACKAGE__->meta->make_immutable;
no Moose;

use Smart::Args;

sub _build_converter {
    args my $self;
    require JSON;
    $self->converter(JSON->new);
}

sub convert {
    args my $self, my $parsed_response => 'HashRef|ArrayRef',
      my $request => 'WebService::Async::Request',
      my $async   => 'WebService::Async';
    return $self->converter->encode($parsed_response);
}

1;

__END__

=head1 NAME

WebService::Async::Converter::JSON - JSON converter class with JSON.

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
