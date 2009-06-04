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

# Modules
use Toolbox qw/indexof/;
use Data::Dumper;

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
		_queued		=>	[],
		_processed	=>	[],
	};
	bless $self, 'Queue';
	return $self;
}

# Add a single url to the queue
sub add {
	my ($self, $url) = @_;
	
	push(@{$self->{_queued}}, $url);
}

# Set the file
sub file {
	my ($self, $file) = @_;
	
	# Configure the file
	$self->{_file} = $file;
	
	# Read a first URL
	$self->file_read();
}

# Add an URL from the file to the queue
sub file_read {
	my ($self) = @_;
	
	if (defined($self->{_file})) {
		open(FILE, $self->{_file});
		while (<FILE>) {
			# Skip things we don't want
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			
			# Process a valid URL
			if ($_ =~ m/^\s*(\S+)\s*/) {
				my $url = $1;
				
				# Only add to queue if not processed yet and not in container either
				if ((indexof($url, $self->{_processed}) == -1) && (indexof($url, $self->{_queued}) == -1)) {
					$self->add($url);
					last;
				}
			}
		}
		close(FILE);
	}
}

# Change the status of an URL (and update the file)
sub file_update {
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

# Get the current url
sub get {
	my ($self) = @_;
	
	# Have we URL's queued up?
	if (scalar(@{$self->{_queued}}) > 0) {
		return @{$self->{_queued}}[0];
	}
	return;
}

# Advance to the next url
sub advance() {
	my ($self) = @_;
	
	# Move the first url from the "queued" array to the "processed" array
	push(@{$self->{_processed}}, shift(@{$self->{_queued}}));
	
	# Check if we still got links in the "queued" array
	unless ($self->get()) {
		$self->file_read();
	}
}	

# Get everything (all URL at once)
# This function will empty the queue, so it should't be used 
# in combination with other functions from the queue
sub dump {
	my ($self) = @_;
	
	my @output;
	
	# Add all URL's to the output
	while (my $url = $self->get()) {
		push(@output, $url);
		$self->advance();
	}
	
	# Return reference
	return \@output;
}

1;
