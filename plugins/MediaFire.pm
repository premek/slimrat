# SlimRat 
# Tomasz [TiMoR] Gągor <timor o2 pl> 2008
# based on Přemek Vyhnal Rapidshare plugin  
# public domain

package MediaFire;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new(agent => 'SlimRat' ); ##############

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/) {
			return 1;
		} else {
			return -1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	$res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}
	else {
		$_ = $res->decoded_content."\n";
		my ($qk,$pk,$r) = m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/sm;
		if(!$qk) {
			print RED "Page #1 error: file doesn't exist or was removed.\n\n"; 
			return 0;
		}
		$res = $mech->get("http://www.mediafire.com/dynamic/download.php?qk=$qk&pk=$pk&r=$r");
		if (!$res->is_success) { print RED "Page #2 error: ".$res->status_line."\n\n"; return 0;}
		else {
			$_ = $res->decoded_content."\n";
			my ($mL,$mH,$mY) = m/var mL='(.+?)';var mH='(\w+)';var mY='(.+?)';.*/sm;
			my ($varname) = m#href=\\"http://"\+mL\+'/'\+ (\w+) \+'g/'\+mH\+'/'\+mY\+'"#sm;
			my ($var) = m#var $varname = '(\w+)';#sm;
			my $download = "http://$mL/${var}g/$mH/$mY";
			return $download;
		}
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?mediafire.com");
