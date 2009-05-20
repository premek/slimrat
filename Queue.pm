#!/usr/bin/env perl
#
# slimrat - URL queue datastructure
#
# Copyright (c) 2009 Tim Besard
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
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

package Queue;

# Write nicely
use strict;
use warnings;

#
# Routines
#

# Constructor
sub new {
	my $self = {
		_file		=>	undef,
		_manual		=>	[],
	};
	bless $self, 'Queue';
	return $self;
}

# Add a single url
sub add {
	my ($self, $url) = @_;

	push(@{$self->{_manual}}, $url);
}

# Set the file
sub file {
	my ($self, $file) = @_;
	
	$self->{_file} = $file;
}

# Get an URL
sub get {
	my ($self) = @_;
	
	# Check if we got manually added urls queue'd up
	if (scalar(@{$self->{_manual}}) > 0) {
		return shift(@{$self->{_manual}});
	}
	
	# Read the file and extract an URL
	elsif (defined($self->{_file})) {
		open(FILE, $self->{_file});
		while (<FILE>) {
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			if ($_ =~ m/^\s*(\S+)\s*/) {
				close(FILE);
				return $1;
			}
		}
		close(FILE);
	}
	
	# All url's processed
	$self->{_empty} = 1;
	return;
}

# Get everything (all URL at once)
sub dump {
	my ($self) = @_;
	
	my @output;
		
	# Manually added URL's
	if (scalar(@{$self->{_manual}}) > 0) {
		foreach (@{$self->{_manual}}) {
			push(@output, $_);
		}
	}
	
	# File contents
	if (defined($self->{file})) {
		open(FILE, $self->{_file});
		while (<FILE>) {
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			if ($_ =~ m/^\s*(\S+)\s*/) {
				push(@output, $1);
			}
		}
		close(FILE);
	}
	
	# Return reference
	return \@output;
}


# Change the status of an URL (and update the file)
sub update {
	my ($self, $url, $status) = @_;
	
	# Only update if we got a file
	if (defined($self->{_file})) {
		open (FILE, $self->{_file});
		open (FILE2, ">".$self->{_file}.".temp");
		while(<FILE>) {
			if (!/^#/ && /$url/) {
				print FILE2 "# ".$status.": ";
			}
			print FILE2 $_;
		}
		close FILE;
		close FILE2;
		unlink $self->{_file};
		rename $self->{_file}.".temp", $self->{_file};
	}	
}

1;
