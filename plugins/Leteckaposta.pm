# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package Leteckaposta;
use LWP::UserAgent;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;


sub download {
	my $file = shift;
	
	$ua = LWP::UserAgent->new;
	$ua->agent("SlimRat");

	$res = $ua->get($file);
	if (!$res->is_success) { print RED "Error: ".$res->status_line."\n\n"; return 0;}
	else {
		($download) = $res->decoded_content =~ m/href='([^']+)' class='download-link'/;
		return "http://leteckaposta.cz$download";
	}
}

Plugin::register(__PACKAGE__, "^[^/]+//(?:www.)?leteckaposta.cz");
1;
