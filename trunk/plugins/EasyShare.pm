# SlimRat 
# Tim Besard <tim.besard gmail com> 2009 
# public domain

package EasyShare;
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
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/msg-err/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	# Get the page
	my $res = $mech->get($file);
	if (!$res->is_success) { print RED "Page error: ".$res->status_line."\n\n"; return 0;}
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n"; 

		if(m/some error message/) {
			($wait) = m/extract some (\d+) minutes/sm;
			print CYAN &ptime."print some message\n";
		} else {
			last;
		}
		
		dwait($wait*60);
		$res = $mech->reload();
	}
	
	# Process the timer
	if (m/Seconds to wait: (\d+)/) {
		my $wait = $1;
		dwait($wait);
	} else {
		print RED, &ptime, "Could not extract Easy-Share wait time\n";
		return 0;
	}
	
	# Extract the code
	my $code;
	if (m/\/file_contents\/captcha_button\/(\d+)/) {
		$code = $1;
	} else {
		print RED, &ptime, "Could not extract Easy-Share captcha code\n";
		return 0;
	}
	
	# Get the second page
	$res = $mech->get('http://www.easy-share.com/c/' . $code);
	$_ = $res->decoded_content."\n";
	
	# Extract the download URL
	my $url;
	if (m/action=\"([^"]+)\" class=\"captcha\"/) {
		$url = $1;
	} else {
		print RED, &ptime, "Could not extract download URL\n";
		return 0;
	}
	
	# Download $file by sending a POST to $url with id=$code && captcha=1
	print "URL is $url, code is $code\n";	

	return 0;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?easy-share.com");

