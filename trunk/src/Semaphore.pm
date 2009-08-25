# slimrat - semaphore structure to guard multithreaded code
#
# Copyright (c) 2009 Tim Besard
# Copyright (c) 2008 Jerry D. Hedden
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
# This code extends the CPAN package Thread::Semaphore, version 2.09.
# The changes between the Modified Version and the Standard Version are:
#   - (slimrat specific) keep a list of currently locked threads in
#     memory, and log that list upon exit (&quit) to ease any
#     attempt to debug a deadlock;
#   - support for reentrant mutexes / recursive semaphores, where
#     the same thread can lock a given semaphore multiple times,
#     without blocking.
# All those features are fully documented in the appended POD.
#
# The Standard Version specified to be licensed under the same
# conditions of Perl, which at the time of writing (2008/08/23)
# is the Artistic License version 1.0. In order to comply with
# this license (section 3, item a) all modifications described
# above are made freely available to the Copyright Holder for
# inclusion in the Standard Version of the Package.
#
# Authors:
#	Jerry D. Hedden <jdhedden AT cpan DOT org>
#	Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

# Package name
package Semaphore;

# Write nicely
use strict;
use warnings;

# Packages
use threads;
use threads::shared;
use Scalar::Util 1.10 qw(looks_like_number);

# Custom packages
use Toolbox;

# Shared data
my %locks : shared;


#
# Static functionality
#

# Quit the package
sub quit {
	return unless scalar(keys %locks);
	my $data;
	foreach my $key (keys %locks) {
		$data .= "Thread ID $key, locked at " . $locks{$key} . ".\n";
	}
	require Log;
	Log::dump_add(title => "locked threads", data => $data, type => "log");
}


#
# Object-oriented functionality
#

# Create a new semaphore optionally with specified count (count defaults to 1)
sub new {
	my $class = shift;
	
	# Object data container (shared hash)
	my $self;
	share($self);
	$self = &share({});
	
	# Semaphore initial value configuration (shared scalar)
	my $val = @_ ? shift : 1;
	if (!defined($val) ||
		! looks_like_number($val) ||
		(int($val) != $val))
	{
		require Carp;
		$val = 'undef' if (! defined($val));
		Carp::croak("Semaphore initializer is not an integer: $val");
	}
	$self->{value} = $val;
	
	# Reentrant mutex handling (shared hash)
	share($self->{reentrant});
	$self->{reentrant} = &share({});
	
	return bless($self, $class);
}

# Decrement a semaphore's count (decrement amount defaults to 1)
sub down {
	my $self = shift;
	lock($self);
	
	# Custom decrement handling
	my $dec = @_ ? shift : 1;
	if (! defined($dec) ||
		! looks_like_number($dec) ||
		(int($dec) != $dec) ||
		($dec < 1))
	{
		require Carp;
		$dec = 'undef' if (! defined($dec));
		Carp::croak("Semaphore decrement is not a positive integer: $dec");
	}
	
	# Reentrant mutex handling
	my $thread = thread_id();
	if ($self->{reentrant}->{$thread}) {
		$self->{reentrant}->{$thread} += $dec;
	} else {
		# Save initial decrement
		$self->{reentrant}->{$thread} = $dec;
		
		# Lock
		$locks{$thread} = (caller(1))[3] . ", line " . (caller(0))[2];
		cond_wait($self) until ($self->{value} >= $dec);
		delete($locks{thread_id()});
	}
	
	# Alter semaphore
	$self->{value} -= $dec;
}

# Increment a semaphore's count (increment amount defaults to 1)
sub up {
	my $self = shift;
	lock($self);
	
	# Custom increment handling
	my $inc = @_ ? shift : 1;
	if (! defined($inc) ||
		! looks_like_number($inc) ||
		(int($inc) != $inc) ||
		($inc < 1))
	{
		require Carp;
		$inc = 'undef' if (! defined($inc));
		Carp::croak("Semaphore increment is not a positive integer: $inc");
	}
	
	# Reentrant mutex handling
	my $thread = thread_id();
	$self->{reentrant}->{$thread} -= $inc;
	
	# Send signal
	($self->{value} += $inc) > 0 and cond_broadcast($self);
}

# Return
1;


#
# Documentation
#

=head1 NAME

Semaphore - Thread-safe semaphores

=head1 SYNOPSIS

	use Semaphore;
	my $s = Semaphore->new();
	$s->down();   # Also known as the semaphore P operation.
	# The guarded section is here
	$s->up();	 # Also known as the semaphore V operation.

	# The default semaphore value is 1
	my $s = Semaphore-new($initial_value);
	$s->down($down_value);
	$s->up($up_value);

	Semaphore::quit();

=head1 DESCRIPTION

Semaphores provide a mechanism to regulate access to resources.  Unlike
locks, semaphores aren't tied to particular scalars, and so may be used to
control access to anything you care to use them for.

Semaphores don't limit their values to zero and one, so they can be used to
control access to some resource that there may be more than one of (e.g.,
filehandles).  Increment and decrement amounts aren't fixed at one either,
so threads can reserve or return multiple resources at once.

=head1 METHODS

=head2 $semaphore->new()

=head2 $semaphore->new(NUMBER)

C<new> creates a new semaphore, and initializes its count to the specified
number (which must be an integer).  If no number is specified, the
semaphore's count defaults to 1.

=head2 $semaphore->down()

=head2 $semaphore->down(NUMBER)

The C<down> method decreases the semaphore's count by the specified number
(which must be an integer >= 1), or by one if no number is specified.

If the semaphore's count would drop below zero, this method will block
until such time as the semaphore's count is greater than or equal to the
amount you're C<down>ing the semaphore's count by.

If however, the same thread has previousely successfully locked the semaphore,
another "P operation" will not result in a locking situation. This is known
as a "reentrant mutex" or "recursive semaphore". Mind though that the actual
semaphore value has effectively been decreased, is it thus obliged to matc
ANY C<down> operation with a corresponding C<up> operation.

This is the semaphore "P operation" (the name derives from the Dutch
word "pak", which means "capture" -- the semaphore operations were
named by the late Dijkstra, who was Dutch).

=head2 $semaphore->up()

=head2 $semaphore->up(NUMBER)

The C<up> method increases the semaphore's count by the number specified
(which must be an integer >= 1), or by one if no number is specified.

This will unblock any thread that is blocked trying to C<down> the
semaphore if the C<up> raises the semaphore's count above the amount that
the C<down> is trying to decrement it by.  For example, if three threads
are blocked trying to C<down> a semaphore by one, and another thread C<up>s
the semaphore by two, then two of the blocked threads (which two is
indeterminate) will become unblocked.

This is the semaphore "V operation" (the name derives from the Dutch
word "vrij", which means "release").

=head2 thread_id()

The C<thread_id> method generates a per-thread unique identifier, internally used
to save data per-thread.

=head2 quit()

The C<quit> method quits the package, which is slimrat-specific functionality.
It adds a dump entry, containing all the currently locked threads (in order to
debug deadlocks).

=head1 NOTES

Semaphores created by L<Semaphore> can be used in both threaded and
non-threaded applications.  This allows you to write modules and packages
that potentially make use of semaphores, and that will function in either
environment.

This package is an extended version of the Thread::Semaphore CPAN package, with
some additional features (list locked threads, reentrant mutexes).

=head1 AUTHOR

Jerry D. Hedden <jdhedden AT cpan DOT org>
Tim Besard <tim-dot-besard-at-gmail-dot-com>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
