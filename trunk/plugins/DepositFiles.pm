# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain
# corrected by Yunnan - www.yunnan.tk 2009 v0.1
# should work with waiting and catches the redownload possibilities without waiting

package DepositFiles;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new(agent => $useragent ); 

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/does not exist/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}


sub download {
	my $file = shift;
	my $res = $mech->get($file);
	if (!$res->is_success) { print "Error: ".$res->status_line."\n\n"; return 0;}
	else {	
		$_ = $mech->content();
		if(m#slots for your country are busy#){print "All downloading slots for your country are busy.\n"; return 0;}
		$re = '<div id="download_url"[^>]>\s*<form action="([^"]+)"';
		if(!(($download) = m#$re#)) {
			$mech->form_number(2);
			$mech->submit_form();
			$_ = $mech->content();
			if(my($wait) = m#Please try in\D*(\d+) min#) {
				main::dwait($wait*60);
				$mech->reload();
				$_ = $mech->content();
			}
			elsif(my($wait) = m#Please try in\D*(\d+) sec#) {
				main::dwait($wait);
				$mech->reload();
				$_ = $mech->content();
			}
			if(m#Try downloading this file again#) {
				($download) = m#<td class="repeat"><a href="([^\"]+)">Try download#;
			} else {
				($wait) = m#show_url\((\d+)\)#;
				main::dwait($wait);
				($download) = m#$re#;
			}
		}
		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?depositfiles.com");
