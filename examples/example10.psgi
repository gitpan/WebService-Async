package Translation;
use Moose;
extends 'Tatsumaki::Handler';

use Tatsumaki::Application;
use Encode qw(decode_utf8);
use WebService::Async::Google::TranslateV1_0;

__PACKAGE__->asynchronous(1);

sub get {
    translate(@_);
}

sub post {
    translate(@_);
}

sub translate {
    my ( $self, $arg ) = shift;
    $self->response->content_type('text/xml');
    my $req    = $self->request;
    my $params = $req->parameters;
    my $src    = $params->get('f');
    $params->remove('f');
    my $dest = $params->get('t');
    $params->remove('t');

    if ( !defined $src || !defined $dest ) {
        # TODO throws an exception.
    }
    my @dest = split '\|', $dest;
    if ( !@dest ) {
        # TODO throws an exception.
    }
    my $service = WebService::Async::Google::TranslateV1_0->new;
    $service->source_language($src);
    $service->set_destination_languages(@dest);
    $params->each(
        sub {
            $service->set_message( decode_utf8( $_[0] ), $_[1] );
        }
    );
    $service->translate(
        on_each_translation => sub {
            my ( $sv, $id, $res ) = @_;
            $self->stream_write($res);
        },
        on_translation_complete => sub {
            my ( $atg, $all_res ) = @_;
            $self->stream_write($all_res);
            $self->finish;
        },
    );
}

my $app = Tatsumaki::Application->new( [
      '/translation/api/get' => 'Translation'
      ] );
return $app;
