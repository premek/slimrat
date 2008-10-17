# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package Rapidshare;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new(agent => 'SlimRat' ); ##############

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $file = shift;
	$mech->get($file);
	$_ = $mech->content();
	return 1 if(m#form id="ff" action#);
	return -1;
}

sub download {
	my $file = shift;

	$res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}
	else {
		$mech->form_number(1); # free (premium=2)
		$res = $mech->submit_form();
		if (!$res->is_success) { print RED "Page #2 error: ".$res->status_line."\n\n"; return 0;}
		else {
			$_ = $res->decoded_content."\n"; 

			if(m/reached the download limit for free-users/) {
				(my $wait) = m/Or try again in about (\d+) minutes/sm;
				print "Waiting $wait minutes before next download.\n";
				main::dwait($wait*60);
				$res = $mech->reload();
				$_ = $res->decoded_content."\n"; 
			}

			if(m/already downloading a file/) {print RED "Already downloading a file\n\n"; return 0;}
			($download, $wait) = m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm;
			main::dwait($wait);

			return $download;
		}
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?rapidshare.com");
