# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

#
# Configuration
#

package Plugin;

use File::Basename;
my ($root) = dirname($INC{'Plugin.pm'});

use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw();

# Write nicely
use strict;
use warnings;

# Static hash for plugins
my %plugins;


#
# Routines
#

# Register a plugin
sub register {
	my ($name,$re) = @_;
	$plugins{$re}=$name;
}

# Get a plugin's name
sub get_name {
	(my $link) = @_;
	foreach my $re (keys %plugins){
		if($link =~ m#$re#i){
			return $plugins{$re};
		}
	}
	return "Direct";
}


#
# "Main"
#

# Let all plugins register themselves
my @pluginfiles = glob "$root/plugins/*.pm";
do $_ || do{system("perl -c $_"); die "\nPlugin $_ failed to load!\n\n"} foreach @pluginfiles;
print "Loaded plugins: "; my $oc = $,; $,=", "; print values %plugins; $, = $oc; print "\n";
scalar @pluginfiles; # no plugins: return false
