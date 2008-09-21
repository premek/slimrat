# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package DepositFiles;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new(agent => 'SlimRat' ); ##############

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	$mech->get(shift);
	return -1 if($mech->content() =~ m#does not exist#);
	return 1;
}


sub download {
	my $file = shift;
	my $res = $mech->get($file);
	if (!$res->is_success) { print "Error: ".$res->status_line."\n\n"; return 0;}
	else {	
		$_ = $mech->content();
		if(m#slots for your country are busy#){print "All downloading slots for your country are busy.\n"; return 0;}
		if(my($err) = m#<strong>(Attention! You used up your limit[^<]*)</strong>#){$err=~s/\s+/ /g; print "$err\n"; return 0;}
		$re = '<div id="download_url"[^>]>\s*<form action="([^"]+)"';
		if(!m#$re#) {
			$mech->form_number(2);
			$mech->submit_form();
			$_ = $mech->content();
			($wait) = m#show_url\((\d+)\)#;
			print "Sleeping for $wait seconds\n";
			sleep $wait;
		}
		($download) = m#$re#;
		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?depositfiles.com");
