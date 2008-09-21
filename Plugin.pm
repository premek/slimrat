# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package Plugin;
use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw();
use File::Basename;
my ($root) = dirname($INC{'Plugin.pm'});


my %plugins;
sub register {
	($name,$re) = @_;
	$plugins{$re}=$name;
}
sub get_name {
	(my $link) = @_;
	foreach $re (keys %plugins){
		if($link =~ m#$re#i){
			return $plugins{$re};
		}
	}
	return "Direct";
}
my @pluginfiles = glob "$root/plugins/*.pm";
do $_ || do{system("perl -c $_"); die "\nPlugin $_ failed to load!\n\n"} foreach @pluginfiles;
print "Loaded plugins: "; my $oc = $,; $,=", "; print values %plugins; $, = $oc; print "\n";
scalar @pluginfiles; # no plugins: return false
