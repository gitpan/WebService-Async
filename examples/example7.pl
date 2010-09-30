#!perl
# Example 7. Asyncronous Request with response converter
use warnings;
use strict;
use Text::MicroTemplate::DataSection 'render_mt';
use WebService::Async;
use WebService::Async::Parser::JSON;
use WebService::Async::Converter::XMLSimple;
use WebService::Async::Converter::Function;

my $wa = WebService::Async->new(
    base_url => 'http://ajax.googleapis.com/ajax/services/language/translate',
    param    => { v => '1.0', langpair => 'en|it' },
    response_parser => WebService::Async::Parser::JSON->new,
    on_done         => sub {
        my ( $sv, $id, $result ) = @_;
        print "${result}\n";
    },
);

# It is useless because you can not relate the request to the response.
# See the __END__ section of this source code.
$wa->response_converter( WebService::Async::Converter::XMLSimple->new );

# You can customize the response by using a custom function.
$wa->whole_response_converter(
    WebService::Async::Converter::Function->new( converter => \&_converter ) );
sub _converter {
    my ( $sv, $request, $parsed_response ) = @_;
    my $converted_reponse =
      render_mt( 'whole_template', $parsed_response )->as_string;
    return $converted_reponse;
}

# translating
$wa->add_get( id => 1, lang => 'fr', param => { q => 'apple', langpair => 'en|fr' } );
$wa->add_get( id => 2, lang => 'it', param => { q => 'orange' } );
$wa->add_get( id => 3, lang => 'it', param => { q => 'grape' } );
my $result = $wa->send_request;
print "${result}\n";

__DATA__
@@ whole_template
<results>
? for my $key ($_[0]->keys_as_hash) {
?   my $text = $_[0]->get($key)->{responseData}->{translatedText};
    <translated id="<?= $key->{id} ?>" lang="<?= $key->{lang} ?>"><?= $text ?></translated>
? }
</results>

__END__
Expected results below.

--- Output from on_done.
--- It is useless because you can not relate the request to the response.
<?xml version="1.0" encoding="UTF-8"?>
<result>
  <responseData>
    <translatedText>mela</translatedText>
  </responseData>
  <responseDetails></responseDetails>
  <responseStatus>200</responseStatus>
</result>

<?xml version="1.0" encoding="UTF-8"?>
<result>
  <responseData>
    <translatedText>uva</translatedText>
  </responseData>
  <responseDetails></responseDetails>
  <responseStatus>200</responseStatus>
</result>

<?xml version="1.0" encoding="UTF-8"?>
<result>
  <responseData>
    <translatedText>arancione</translatedText>
  </responseData>
  <responseDetails></responseDetails>
  <responseStatus>200</responseStatus>
</result>
---

--- Output from send_request
--- Relating the request to the resposne by using the key.
<results>
    <translated id="3" lang="it">uva</translated>
    <translated id="1" lang="fr">Apple</translated>
    <translated id="2" lang="it">arancione</translated>
</results>
---

