# SlimRat 
# Gabor Bognar <wade at wade dot hu>  2009 
# public domain

package DataHu;
use Toolbox;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use WWW::Mechanize;
use strict;
use warnings;
use Data::Dumper;

my $mech = WWW::Mechanize->new('agent'=>$useragent);

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $file = shift;
	$mech->get($file);
	$_ = $mech->content();
	return -1 if(m#error_box#);
	return 1;
}

sub download {
	my $file = shift;

	my $res = $mech->get($file);
	if (!$res->is_success) { print RED "Plugin error: ".$res->status_line."\n\n"; return 0;}

	$_ = $res->decoded_content."\n"; 
	my $ok = 0;
	while(!$ok){
		my $wait;


		if(m#kell:#) {
			$ok=0;
			($wait) = m#<div id="counter" class="countdown">(\d+)</div>#sm;
			dwait($wait);
			$res = $mech->reload();
			$_ = $res->decoded_content."\n"; 
		} else {
			$ok=1;
		}
	}

	my ($download) = m/class="download_it"><a href="(.*)" onmousedown/sm;
	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?data.hu");
