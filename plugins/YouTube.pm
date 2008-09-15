# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package YouTube;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
#use WWW::Mechanize;
#my $mech = WWW::Mechanize->new(agent => 'SlimRat' ); ##############

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $ua->get(shift);
	return 1 if ($res->is_success && $res->content()!~m#<div class="errorBox">#);
	return -1;
}

sub download {
	my $paramChar = '[\w\d-_]';
	my ($v) = shift =~ m#\Wv=($paramChar+)#;
	my ($t) = $ua->head("http://www.youtube.com/v/$v")->{_previous}->header('location') =~ m#\Wt=($paramChar+)#;
	return "http://www.youtube.com/get_video.php?video_id=$v&t=$t";
}

Plugin::register(__PACKAGE__,"^[^/]+//[^.]*\.?youtube\.com/watch[?]v=.+");
