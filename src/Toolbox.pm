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

# Package name
package Toolbox;

# Packages
use threads;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(dwait indexof timestamp bytes_readable seconds_readable readable2bytes thread_id wait);

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

# Generate a timestamp
sub timestamp {
	my ($sec,$min,$hour) = localtime;
	sprintf "[%02d:%02d:%02d] ",$hour,$min,$sec;
}

# Convert a raw amount of bytes to a more human-readable form
sub bytes_readable {
	my $bytes = shift;
	return "unknown" if ($bytes == -1);
	
	my $bytes_hum = "$bytes";
	if ($bytes>=2**30) { $bytes_hum = ($bytes / 2**30) . " GB" }
	elsif ($bytes>=2**20) { $bytes_hum = ($bytes / 2**20) . " MB" }
	elsif ($bytes>=2**10) { $bytes_hum = ($bytes / 2**10) . " KB" }
	else { $bytes_hum = $bytes . " B" }
	$bytes_hum =~ s/(^\d{1,}\.\d{2})(\d*)(.+$)/$1$3/;
	
	return $bytes_hum;
}

# Return seconds in m:ss format
sub seconds_readable {
	my $sec = shift || return "0:00";
	return "unknown" if ($sec == -1);
	my $s = $sec % 60;
	my $m = ($sec - $s) / 60;
	# TODO hours???
	return sprintf('%d:%02d', $m, $s);
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

# Generate a per-thread ID
sub thread_id {
	my $thr = threads->self();
	my $tid = $thr->tid();
	return $tid;
}

# Wait a while
sub wait {
	my $wait = shift or return;
	require Log;
	info(sprintf("Waiting ".seconds_readable($wait)));
	sleep($wait);
}

# Return
1;
