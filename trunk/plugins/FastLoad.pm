# SlimRat 
# Tomasz [TiMoR] Gągor <timor o2 pl> 2008
# based on Přemek Vyhnal Rapidshare plugin  
# public domain

package FastLoad;
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
	return 1 if(m#name="fid" value#);
	return -1;
}

sub download {
	my $file = shift;

	$res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}
	else {
		$_ = $res->content."\n";
		($fname) = m/<span style="font-color:grey; font-weight:normal; font-size:8pt;">(.+?)<\/span>/s;
		if(!$fname) {print RED "Can't find file name.\n\n"; return 0;}
		($fid) = m/name="fid" value="(\w+)"/sm;
		if(!$fid) {print RED "Can't find fid number.\n\n"; return 0;}
		my $download = "http://www.fast-load.net/download.php' --post-data 'fid=".$fid."' -O '".$fname;

		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?fast-load.net");
