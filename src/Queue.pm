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
use Log;

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
		_queued		=>	[],	# Anonymous array
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
	
	fatal("file `$file' not readable") unless (-r $file);

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
			if (!/^#/ && m/\Q$url\E/) { # Quote (de-meta) metacharacters between \Q and \E
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
		return $self->{_queued}->[0];
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

# Return
1;

__END__

=head1 NAME 

Queue

=head1 SYNOPSIS

  use Queue;

  # Configure a queue
  my $queue = Queue::new();
  $queue->add('http://test.url/file');
  $queue->file('/tmp/urls.dat');
  
  # Process all URL's
  while (my $url = $queue->get) {
    print "Got an URL: $url\n";
    $queue->advance();
  }

=head1 DESCRIPTION

This package provides a queue-based datastructure for URLS, with additional file
support. It behaves like you expect a queue to behave (functionality to add an URL,
fetch the last one, remove it, and check if there are URL's available). When however
a file has been provided, the Queue will fill itself with data from that file
when the internal queue seems empty.

The file-handling also supports duplicate URL's (which will be avoided), comments, and
updating (= commenting out URL's with a given prefix) URL's from the file.

=head1 METHODS

=head2 Queue::new()

This constructs a new Queue, with initially no data at all.

=head2 $queue->add()

This adds an URL to the back of the queue.

=head2 $queue->get()

This fetches the first URL from the queue, without removing it.

=head2 $queue->advance()

This advances to the next URL, e.g. by removing the first one, and unless there are
still URL's queued up, fetch one from the file (if set).

=head2 $queue->file()

Give the queue access to a file. This also triggers a read, so if you want to priorityze
URL's make sure they have been added before the file() call.

=head2 $queue->file_read()

Read a single URL from the file. Comments and already processed or enqueued URL's will be
skipped.

=head2 $queue->file_update($url, $status)

Comment out a given URL, and prepend a status
  # STATUS: url

=head2 $queue->dump()

Dump the contents of the queue in the form of an array. This is a one-time only function, e.g.
it renders the queue unusable and does not attempt to preserve any state at all.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

