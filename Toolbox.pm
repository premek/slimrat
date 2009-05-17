# SlimRat 
# Přemek Vyhnal <premysl.vyhnal gmail com> 2009 
# public domain

package Toolbox;

use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(dwait ptime $useragent);

use strict;
use warnings;

our $useragent = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624";

sub dwait{
	my ($wait, $rem, $sec, $min);
	$wait = $rem = shift or return;
	$|++; # unbuffered output;
	($sec,$min) = localtime($wait);
	printf(&ptime."Waiting %02d:%02d\n",$min,$sec);
	sleep ($rem);
}

sub ptime {
	my ($sec,$min,$hour) = localtime;
	sprintf "[%02d:%02d:%02d] ",$hour,$min,$sec;
}


1;
