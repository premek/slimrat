# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain
#
# thanks to Bartłomiej Palmowski
#

package YouTube;
use Toolbox;
use WWW::Mechanize;
my $mech = WWW::Mechanize->new('agent'=>$useragent );

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/<div class="errorBox">/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

sub download {
	my ($v, $t) = $mech->get(shift)->decoded_content =~ /swfArgs.*"video_id"\s*:\s*"(.*?)".*"t"\s*:\s*"(.*?)".*/;
	return "http://www.youtube.com/get_video?video_id=$v&t=$t";
}

Plugin::register(__PACKAGE__,"^[^/]+//[^.]*\.?youtube\.com/watch[?]v=.+");
