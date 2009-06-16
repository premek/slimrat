#!/usr/bin/env perl
#
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
@ISA=qw(Exporter);
@EXPORT=qw(dwait indexof $useragent);

# Write nicely
use strict;
use warnings;

# Modules
use Log;

# Fake a user agent
our $useragent = "Mozilla/5.0 (Windows; U; Windows NT 6.1; pl; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10";


#
# Routines
#

# Wait a while
sub dwait{
	my ($wait, $rem, $sec, $min);
	$wait = $rem = shift or return;
	$|++; # unbuffered output;
	($sec,$min) = localtime($wait);
	info("Waiting $min:$sec");
	sleep($rem);
}

# Look for the index of an item in an array (non-numeric contents)
sub indexof {
	my ($value, $arrayref) = (shift, shift);
	foreach my $i (0 .. @$arrayref-1)  {
		return $i if $$arrayref[$i] eq $value;
	}
	return -1;
}

# Return
1;
