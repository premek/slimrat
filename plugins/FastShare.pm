#!/usr/bin/env perl
#
# SlimRat plugin for FastShare v0.1
# Yunnan www.yunnan.tk 2009.04
# public domain
# partially based on other plugins
#

package FastShare;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
#use Toolbox;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new('agent' => $useragent );

# return - as usual
#   1: ok
#  -1: dead
#   0: don't know

sub check {
	$mech->get(shift);
	return -1 if($mech->content() =~ m/No filename specified or the file has been deleted!/);
	return 1  if($mech->content() =~ m/klicken sie bitte auf Download!/);
	return 0;
}

sub download {
	my $file = shift;
	$res = $mech->get($file);
	if (!$res->is_success) { print RED "Plugin error: ".$res->status_line."\n\n"; return 0;}
	else {
		$mech->form_number(0);
		$mech->submit_form();
		$_ = $mech->content;
		($download) = m/<br>Link: <a href=([^>]+)><b>/s;
		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?fastshare.org");

