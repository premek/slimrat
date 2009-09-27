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
use Storable;

# Custom packages
use Configuration;
use Semaphore;
use Toolbox;
use Log;

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;

# Shared data
my $s_file:shared = new Semaphore;	# Semaphore here manages file access
my @queued:shared; my $s_queued:shared = new Semaphore;
my @processed:shared; my $s_processed:shared = new Semaphore;
my %busy:shared; my $s_busy:shared = new Semaphore;


#
# Static functionality
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	
	$config->path_abs("file");
}

# Add a single url to the queue
sub add {
	my $url = shift;
	return unless $url;
	
	$s_queued->down();
	push(@queued, $url);
	$s_queued->up();
}

# Add an URL from the file to the queue
sub file_read {
	return 0 unless ($config->contains("file") && -r $config->get("file"));
	debug("reading queue file '", $config->get("file") ,"'");
	my $added = 0;
	
	$s_file->down();
	open(FILE, $config->get("file")) || fatal("could not read queue file");
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
			$s_busy->down();
			my @values = values %busy;
			if ((indexof($url, \@processed) == -1) && (indexof($url, \@queued) == -1) && (indexof($url, \@values) == -1)) {
				$s_busy->up();
				$s_queued->up();
				$s_processed->up();
				add($url);
				$added = 1;
				last;
			}
			$s_busy->up();
			$s_queued->up();
			$s_processed->up();
		} else {
			warning("unrecognised line in queue file: '$_'");
		}
	}
	close(FILE);
	$s_file->up();
	return $added;
}

# Get everything (all URLs at once)
sub dump {	
	my @output;
	
	# Add all URL's to the output
	my $queue = new Queue();
	$queue->advance();
	while (my $url = $queue->get()) {
		push(@output, $url);
		$queue->skip_locally();
		$queue->advance();
	}
	
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
	$s_processed->up();
	$s_queued->up();
}

# Save the state of the queue object
sub save($) {
	my $filename = shift;
	$s_queued->down();
	$s_processed->down();
	my %container = (
		queued		=>	[@queued],
		processed	=>	[@processed]
	);
	$container{file} = $config->get("file") if $config->contains("file");
	store(\%container, $filename) || error("could not serialize queue to '$filename'");
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
		if (defined($container{file})) {
			if ($config->get("file")) {
				warning("active instance already got a queue file defined, not overwriting");
			} else {
				$config->set("file", $container{file});
			}
		}
		@queued = @{$container{queued}};
		@processed = @{$container{processed}};
		$s_queued->up();
		$s_processed->up();
	}
}

# Quit the package
sub quit {

}


#
# Object-oriented functionality
#

# Constructor
sub new {
	my $self = {
		item		=>	undef,
		status		=>	"",
		processed	=>	[]
	};
	bless $self, 'Queue';
	
	return $self;
}

# Destructor
sub DESTROY {
	my ($self) = @_;
	
	if (defined($self->{item}) && !$self->{status}) {
		debug("found queued item without status, unblocking and merging back to main queue");
		
		$self->{item} = undef;
		$s_busy->down();
		delete($busy{thread_id()});
		$s_busy->up();
		
		$s_queued->down();
		push(@queued, $self->{item});
		$self->{item} = undef;
		$s_queued->up();
	}
}

# Get the current url
sub get {
	my ($self) = @_;
	return $self->{item};
}

# Advance to the next url
sub advance($) {
	my ($self) = @_;
	
	fatal("advance call should always be preceded by skip_* call") if ($self->{item});
	
	# Fetch a new item from static queue cache
	$s_queued->down();
	for (my $i = 0; $i <= $#queued; $i++) {
		if (!scalar($self->{processed}) || indexof($queued[$i], $self->{processed}) == -1) {
			$self->{item} = delete($queued[$i]);
		
			# Fix the "undef" gap delete creates (variant which preserves order)
			# (which does not happen if "delete" deleted last element)
			if ($i != scalar(@queued)) {
				for my $j ($i ... $#queued-1) {
					$queued[$j] = $queued[$j+1];
				}
				pop(@queued);
			}
			last;
		}
	}
	$s_queued->up();
	
	# Fetch a new item from reading the file
	if (!$self->{item}) {
		$s_queued->down();
		while (!$self->{item} || indexof($self->{item}, $self->{processed}) != -1) {
			unless (file_read()) {
				$s_queued->up();
				debug("queue exhausted");
				return 0;
			}
			$self->{item} = pop(@queued);
			
		}
		$s_queued->up();
	}
	
	# Mark the item as being in use
	$s_busy->down();
	$busy{thread_id()} = $self->{item};
	$s_busy->up();
	
	return 1;
}

# Change the status of an URL (and update the file)
sub skip_globally {
	my ($self, $status) = @_;
	
	# Update the status if requested
	if ($status) {
		$self->{status} = $status;
	
		# Only update if we got a file
		my $url = $self->{item};
		$s_file->down();
		if ($config->contains("file") && -r $config->get("file")) {
			open (FILE, $config->get("file"));
			open (FILE2, ">".$config->get("file").".temp");
			while(<FILE>) {
				if (!/^#/ && m/\Q$url\E/) { # Quote (de-meta) metacharacters between \Q and \E
					print FILE2 "# ".$self->{status}.": ";
				}
				print FILE2 $_;
			}
			close FILE;
			close FILE2;
			unlink $config->get("file");
			rename $config->get("file").".temp", $config->get("file");
		}
		$s_file->up();
	}
	
	# Move the queued item to the "processed" array
	$s_processed->down();
	push(@processed, $self->{item});	
	$s_processed->up();
	
	# Reset the item
	$self->{item} = undef;
	$s_busy->down();
	delete($busy{thread_id()});
	$s_busy->up();
}

# Skip to the next url
sub skip_locally($) {
	my ($self) = @_;	
	
	# Move the queued item to the "queued" array, and to the local "processed" array
	$s_queued->down();
	unshift(@queued, $self->{item});	
	$s_queued->up();
	push(@{$self->{processed}}, $self->{item});
	
	# Reset the item
	$self->{item} = undef;
	$s_busy->down();
	delete($busy{thread_id()});
	$s_busy->up();
}

# Return
1;


#
# Documentation
#

=head1 NAME 

Queue

=head1 SYNOPSIS

  use Queue;
  
  # Configure the static queue cache
  Queue::add("http://test.url.file");
  Queue::file("/data/file_with_urls");

  # Configure a queue
  my $queue = Queue::new();
  my $url = $queue->get();

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

=head2 Queue::reset()

Resets the queue, by erasing all internal datastructures.

=head2 Queue::restart()

Restarts already processed downloads, by resetting certain internal arrays which
control which URLs should be processed and which shouldn't. Can be used in combination
with a file to read URLs from to give URLs which have been processed (and advanced from)
but not commented out another chance.

=head2 Queue::add()

This adds an URL to the back of the queue.

=head2 Queue::file()

Give the queue access to a file. This also triggers a read, so if you want to priorityze
URL's make sure they have been added before the file() call.

=head2 Queue::file_read()

Read a single URL from the file. Comments and already processed or enqueued URLs will be
skipped.

=head2 Queue::dump()

Return all the following URLs, e.g. dump the entire queue. This does respect already
processed URLs, and keeps the queue reusable by restoring it state after running.

=head2 $queue->get()

This fetches the first URL from the queue object.

=head2 $queue->advance()

This advances to the next URL. Mind though that this instruction always has to be preceded by a
skip_* function, or the resulting URL will be the same as before.

=head2 $queue->skip_locally()

Make sure the current URL won't be used by this queue object anymore. This invalidates the current item.

=head2 $queue->skip_glibally($status)

Make sure the current URL won't be used by any queue object anymore. This invalidates the current item.
Optionally with a given $status, which will (if possible) be used to comment out the url in the queue
file and prepend it with the given status.
  # STATUS: url

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

