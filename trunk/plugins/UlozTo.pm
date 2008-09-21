# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package UlozTo;
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
	return 1 if(m#<form action="http://dld.uloz.to#);
	return -1;
}

sub download {
# nefunguje
	my $file = shift;
	$mech->get($file);
	@links = $mech->find_all_links();
	return $links[14]->[0];
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?uloz.to");
