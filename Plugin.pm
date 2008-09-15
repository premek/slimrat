# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package Plugin;
use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw();


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
my @pluginfiles = glob $INC[0].'/plugins/*.pm';
do $_ foreach @pluginfiles;
scalar @pluginfiles # no plugins - return false
