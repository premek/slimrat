# slimrat - several frequently-used subroutines
#
# Copyright (c) 2008-2009 Přemek Vyhnal
#
# This file is part of slimrat, an open-source Perl scripted
# command line and GUI utility for downloading files from
# several download providers.
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# Authors:
#    Přemek Vyhnal <premysl.vyhnal gmail com> 
#

#
# Configuration
#

package Toolbox;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(dwait indexof readable2bytes);

# Write nicely
use strict;
use warnings;


#
# Routines
#

# Look for the index of an item in an array (non-numeric contents)
sub indexof {
	my ($value, $arrayref) = (shift, shift);
	return -1 unless $arrayref;
	foreach my $i (0 .. @$arrayref-1)  {
		return $i if $$arrayref[$i] eq $value;
	}
	return -1;
}

# Converts human readable size to bytes 
# 10.5 KB  10M  10 B  ...
# Case insensitive! k=K=2**10, b=B=byte - FIXME?? 
sub readable2bytes {
	$_ = shift;
	s/\s+//g;
	s/(\d+),(\d+)/$1.$2/;
	my %mul = (K=>2**10, M=>2**20, G=>2**30);
	if    (/(\d+(?:\.\d+)?)([KMG])B?/i) { return $1 * $mul{uc($2)} }
	elsif (/(\d+(?:\.\d+)?)B?/i)        { return $1 }
	else {return 0}
}

# Return
1;
