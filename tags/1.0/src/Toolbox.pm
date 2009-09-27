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
use File::Spec;

# Custom packages
use Configuration;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(indexof timestamp bytes_readable seconds_readable readable2bytes thread_id wait rel2abs);

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("skip_waits", 0);


#
# Static functionality
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
}

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
	my $input = shift || return "0:00";
	return "unknown" if ($input == -1);
	
	my $seconds = $input % 60;
	$input /= 60;
	
	my $minutes = $input % 60;
	$input /= 60;
	
	my $hours = int($input);
	
	if ($hours) {
		return sprintf('%dh %d:%02d', $hours, $minutes, $seconds);
	} else {
		return sprintf('%d:%02d', $minutes, $seconds);
	}
}

# Converts human readable size to bytes 
# Case insensitive because most sites don't respect
# SI conventions (k=K=2**10, but b=bit != B=byte)
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
# $1: seconds to wait
# $2: this wait can be skipped if true
sub wait {
	my $wait = shift or return;
	return if (shift and $config->get("skip_waits"));
	require Log;
	Log::info(sprintf("Waiting ".seconds_readable($wait)));
	#sleep($wait);
	# TODO: sleep() postpones SIG_INT till end of sleep
	while ($wait) {
		$wait -= 1;
		sleep(1);
	}
}

sub rel2abs {
	return File::Spec->rel2abs(@_);
}

# Return
1;
