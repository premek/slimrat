# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2008 
# public domain

package Direct;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

sub download {
	return shift;
}


sub check {
	return 1 if ($ua->head(shift)->is_success);
	return -1;
}
1;
