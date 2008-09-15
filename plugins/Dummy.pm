# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain
#
# template for new plugins

package Dummy;

sub download {
	my $file = shift;
	
	return "http://url.of/file/to/down.load";
}


# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $file = shift;
	return 0;
}

# uncomment this. 
# Plugin::register(__PACKAGE__, "^[^/]+//(?:www.)?some#site.cz"); # regexp to match the url downloadable by this plugin
