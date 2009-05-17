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

# Maximum wait interval (in minutes)
my $wait_max = 2;

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

	# Get the primary page
	my $res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}
	
	# Click the "Free" button
	$mech->form_number(1);
	$res = $mech->submit_form();
	if (!$res->is_success) { print RED "Page #2 error: ".$res->status_line."\n\n"; return 0;}
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n"; 

		if(m/reached the download limit for free-users/) {
			($wait) = m/Or try again in about (\d+) minutes/sm;
			print CYAN &ptime."Reached the download limit for free-users\n";
			
		} elsif(($wait) = m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
			print CYAN &ptime."Currently a lot of users are downloading files\n";
		} elsif(($wait) = m/no available slots for free users\. Unfortunately you will have to wait (\d+) minutes/) {
			print CYAN &ptime."No available slots for free users\n";

		} elsif(m/already downloading a file/) {
			print CYAN &ptime."Already downloading a file\n"; 
			$wait = 60;
		} else {
			last;
		}
		
		if ($wait > $wait_max) {
			print &ptime."Should wait $wait minutes, interval-check in $wait_max minutes\n";
			$wait = $wait_max;
		}
		dwait($wait*60);
		$res = $mech->reload();
	}

	my ($download, $wait) = m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm;
	dwait($wait);

	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?rapidshare.com");
