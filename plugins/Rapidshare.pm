# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2009 
# public domain

package Rapidshare;
use Toolbox;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use WWW::Mechanize;
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent'=>$useragent);

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

	my $res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}

	$mech->form_number(1); # free;
	$res = $mech->submit_form();
	if (!$res->is_success) { print RED "Page #2 error: ".$res->status_line."\n\n"; return 0;}

#$_ = $res->decoded_content."\n"; 
	my $ok = 0;
	while(!$ok){
		my $wait;

		$res = $mech->reload();
		$_ = $res->decoded_content."\n"; 

		if(m/reached the download limit for free-users/) {
			$ok=0;
			($wait) = m/Or try again in about (\d+) minutes/sm; # somebody said we don't have to wait that much (??);
			print CYAN &ptime."Reached the download limit for free-users\n";
			dwait($wait*60);

		} elsif(($wait) = m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
			$ok=0;
			print CYAN &ptime."Currently a lot of users are downloading files\n";
			dwait($wait*60);
		} elsif(($wait) = m/no available slots for free users\. Unfortunately you will have to wait (\d+) minutes/) {
			$ok=0;
			print CYAN &ptime."No available slots for free users\n";
			dwait($wait*60);
		} elsif(m/already downloading a file/) {
			$ok=0;
			print CYAN &ptime."Already downloading a file\n"; 
			dwait(60);
		} else {
			$ok=1;
		}
	}

	my ($download, $wait) = m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm;
	dwait($wait);

	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?rapidshare.com");
