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

# Package name
package Queue;

# Packages
use threads;
use threads::shared;
use Thread::Semaphore;
use Storable;

# Custom packages
use Configuration;
use Toolbox;
use Log;

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;

# Shared data
my $file:shared; my $s_file:shared = new Thread::Semaphore;	# Semaphore here manages file _access_, not $file access
my @queued:shared; my $s_queued:shared = new Thread::Semaphore;
my @processed:shared; my $s_processed:shared = new Thread::Semaphore;


#
# Static functionality
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	file_read();
}

# Set the file
sub file {
	my $filename = shift;
	return error("cannot overwrite previously set file") if (defined($file));
	$file = $filename;
	
	fatal("queue file '$file' not readable") unless (-r $file);
	
	# Read a first URL
	file_read();
}

# Add a single url to the queue
sub add {
	my $url = shift;
	
	$s_queued->down();
	push(@queued, $url);
	$s_queued->up();
}

# Add an URL from the file to the queue
sub file_read {
	if (defined($file)) {
		debug("reading queue file '$file'");
		$s_file->down();
		open(FILE, $file) || fatal("could not read queue file (NOTE: when daemonized, use absolute paths)");
		while (<FILE>) {
			# Skip things we don't want
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			
			# Process a valid URL
			if ($_ =~ m/^\s*(\S+)\s*/) {
				my $url = $1;
				
				# Only add to queue if not processed yet and not in container either
				$s_processed->down();
				$s_queued->down();
				if ((indexof($url, @processed) == -1) && (indexof($url, @queued) == -1)) {
					$s_queued->up();
					$s_processed->up();
					add($url);
					last;
				}
				$s_queued->up();
				$s_processed->up();
			} else {
				warning("unrecognised line in queue file: '$_'");
			}
		}
		close(FILE);
		$s_file->up();
	}
}

# Get everything (all URLs at once)
sub dump {	
	my @output;
	
	# Backup the internal data
	$s_processed->down();
	$s_queued->down();
	my @processed_bak = @processed;
	my @queued_bak = @queued;
	$s_queued->up();	# FIXME: use reentrant mutexes
	
	# Add all URL's to the output
	my $queue = new Queue();
	while (my $url = $queue->get()) {
		push(@output, $url);
		$s_processed->up();	# FIXME: use reentrant mutexes
		$queue->advance();
		$s_processed->down();
	}
	$s_queued->down();
	
	# Restore the backup
	@processed = @processed_bak;
	@queued = @queued_bak;
	$s_queued->up();
	$s_processed->up();
	
	# Return reference
	return \@output;
}

# Restart processed downloads
sub restart() {
	$s_processed->down();
	@processed = [];
	$s_processed->up();
	debug("resetting state of processed URLs");
}

# Reset the queue
sub reset() {
	$s_queued->down();
	$s_processed->down();
	@queued = ();
	@processed = ();
	$file = undef;
	$s_processed->up();
	$s_queued->up();
}

# Save the state of the queue object
sub save($) {
	my $filename = shift;
	$s_queued->down();
	$s_processed->down();
	my %container = (
		file		=>	$file,
		queued		=>	[@queued],
		processed	=>	[@processed]
	);
	store(\%container, $filename) || error("could not serialize queue to '$file'");
	$s_queued->up();
	$s_processed->up();
}

# Restore the state of the queue object
sub restore {
	my $filename = shift;
	my %container;
	if (-f $filename) {
		eval { %container = %{retrieve($filename)} };
		return error("could not reconstruct queue out of '$filename'") if ($@);
		
		$s_queued->down();
		$s_processed->down();
		$file = $container{file};
		@queued = @{$container{queued}};
		@processed = @{$container{processed}};
		$s_queued->up();
		$s_processed->up();
	}
}


#
# Object-oriented functionality
#

# Constructor
sub new {
	my $self = {
		item	=>	undef,
		status	=>	""
	};
	bless $self, 'Queue';
	
	# Load a first URL
	$self->advance();
	
	return $self;
}

# Destructor
sub DESTROY {
	my ($self) = @_;
	
	if (defined($self->{item}) && !$self->{status}) {
		debug("found queued item without status, merging back to main queue");
		$s_queued->down();
		push(@queued, $self->{item});
		$self->{item} = undef;
		$s_queued->up();
	}
}

# Change the status of an URL (and update the file)
sub update {
	my ($self, $status) = @_;
	$self->{status} = $status;
	
	# Only update if we got a file
	my $url = $self->{item};
	$s_file->down();
	if (defined($file)) {
		open (FILE, $file);
		open (FILE2, ">".$file.".temp");
		while(<FILE>) {
			if (!/^#/ && m/\Q$url\E/) { # Quote (de-meta) metacharacters between \Q and \E
				print FILE2 "# ".$self->{status}.": ";
			}
			print FILE2 $_;
		}
		close FILE;
		close FILE2;
		unlink $file;
		rename $file.".temp", $file;
	}
	$s_file->up();
}

# Get the current url
sub get {
	my ($self) = @_;
	return $self->{item};
}

# Advance to the next url
sub advance() {
	my ($self) = @_;
	
	# Move the first url from the "queued" array to the "processed" array
	if (defined($self->{item})) {
		$s_processed->down();
		push(@processed, $self->{item});	
		$s_processed->up();
	}
	
	# Load a new item
	$self->{item} = undef;
	$s_queued->down();
	if (! scalar(@queued)) {
		$s_queued->up();	# TODO: use reentrant mutexes / recursive semaphores
		file_read();
		$s_queued->down();
	}
	$self->{item} = shift(@queued);
	$s_queued->up();
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

=head2 Queue::new($file)

This constructs a new Queue, with data restored from the given file $file. That
file should contain data which has been saved using the save($file) routine.

=head2 Queue::save($file)

This saves the data from the queue in a file, by serializing it. Can be restored
through a constructor with given filename.

=head2 $queue->reset()

Resets the queue, by erasing all internal datastructures.

==head2 $queue->restart()

Restarts already processed downloads, by resetting certain internal arrays which
control which URLs should be processed and which shouldn't. Can be used in combination
with a file to read URLs from to give URLs which have been processed (and advanced from)
but not commented out another chance.

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

Read a single URL from the file. Comments and already processed or enqueued URLs will be
skipped.

=head2 $queue->file_update($url, $status)

Comment out a given URL, and prepend a status
  # STATUS: url

=head2 $queue->dump()

Return all the following URLs, e.g. dump the entire queue. This does respect already
processed URLs, and keeps the queue reusable by restoring it state after running.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

