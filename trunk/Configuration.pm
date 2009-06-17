#!/usr/bin/env perl
#
# slimrat - configuration handling
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
# Configurationuration
#

# Package name
package Configuration;

# Modules
use Class::Struct;
use Toolbox;
use Log;

# Write nicely
use strict;
use warnings;

# A configuration item
struct(Item =>	{
			default		=>	'$',
			mutable		=>	'$',
			values		=>	'@',
});


#
# Internal routines
#

# Create a new item
sub init($$) {
	my ($self, $key) = @_;
	
	if ($self->contains($key)) {
		warning("attempt to overwrite existing key through initialisation, bailing out");
		return 0;
	}
	
	my $item = new Item;
	$item->mutable(1);
	
	$self->{_items}->{$key} = $item;
	
	return 1;
}

# Get the amount of stacked up items
sub items($$) {
	my ($self, $key) = @_;
	return -1 unless ($self->contains($key));
	return scalar(@{$self->{_items}->{$key}->values});
}


#
# Routines
#

# Constructor
sub new {
	my $self = {
		_items		=>	{},	# Anonymous hash
	};
	bless $self, 'Configuration';
	return $self;
}

# Check if the configuration contains a specific key
sub contains($$) {
	my ($self, $key) = @_;
	if (exists $self->{_items}->{$key}) {
		return 1;
	} else {
		return 0;
	}
}

# Add a default value
sub add_default($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if key contains
	if ($self->contains($key)) {
		if (! $self->{_items}->{$key}->mutable) {
			warning("attempt to change default value of protected key \"$key\"");
			return 0;
		}
	} else {
		$self->init($key);
	}
	
	# Update the default value
	$self->{_items}->{$key}->default($value);
}

# Get a value
sub get($$) {
	my ($self, $key) = @_;
	
	# Check if it contains the key (not present returns false)
	return 0 unless ($self->contains($key));
	
	# Check if values available
	if ($self->items($key) > 0) {
		return $self->{_items}->{$key}->values->[-1];
	} else {
		return $self->{_items}->{$key}->default;
	}
}

# Set a value
sub add($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if contains
	if (!$self->contains($key)) {
		$self->add_default($key, undef);
	}
	
	# Check if mutable
	if (! $self->{_items}->{$key}->mutable) {
		warning("attempt to modify protected key \"$key\"");
		return 0;
	}
	
	# Modify value
	push(@{$self->{_items}->{$key}->values}, $value);
	return 1;
}

# Revert a value
sub revert($$) {
	my ($self, $key) = @_;
	if ($self->items($key) > 0) {
		pop(@{$self->{_items}->{$key}->values});
		return 1;
	}
	return 0;
}

# Protect an item
sub protect($$) {
	my ($self, $key) = @_;
	if ($self->contains($key)) {
		$self->{_items}->{$key}->mutable(0);
		return 1;
	}
	return 0;
}

# Read a file
sub file_read($$) {
	my ($self, $file) = @_;
	open(READ, $file) || fatal("could not open configuration file \"$file\"");
	while (<READ>) {
		chomp;
		
		# Skip comments, and leading & trailing spaces
		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		
		# Get the key/value pair
		if (/^(.+?)\s*(=+)\s*(.+?)$/) {		# The extra "?" makes perl prefer a shorter match (to avoid "\w " keys)
			$self->add($1, $3);
			$self->protect($1) if (length($2) >= 2);
		} else {
			warning("ignored invalid configuration file entry \"$_\"");
		}
	}
	close(READ);
}

# Return
1;

__END__

=head1 NAME 

Configuration

=head1 SYNOPSIS

  use Configuration;

  # Construct the configuration handles
  my $config = Configuration::new();

=head1 DESCRIPTION

This package provides a configuration handler, which should ease the use
of several inputs for configuration values, including their default values.

=head1 METHODS

=head2 Configuration::new()

This constructs a new configuration object, with initially no contents at all.

=head2 $config->add_default($key, $value)

Adds a new item into the configuration, with $value as default (!) value. This
only updates an existing key if it was not been marked as protected. Newly created
keys are always made mutable at first.

=head2 $config->add($key, $value)

Add a value to a specific key in the configuration. This is kept separated from the
default value, so one can still access the default value (and all previousely entered
values!) after adding a new value through this routine.
If nonexistant, the item gets created, by default mutable with "undef" as default value.

=head2 $config->get($key)

Return the value for a specific key. Returns 0 if not found, and if found but no values
are found it returns the default value (which is "undef" if not specified).

=head2 $config->contains($key)

Check whether a specific key has been entered in the configuration (albeit by default
or customized value).

=head2 $config->revert($key)

Revert values, up to when no values are available no more upon which the fucnction returns 0.
This can be used by specifying a valid default value, and looping the manually specified values
through a while-loop:
  my $number = $config->get("number");
  while ($number !~ /^\d$/) {
  	$config->revert("number") || die("no valid number found");
  	$number = $config->get("number");
  }
  print "Number is $number\n";

=head2 $config->protect($key)

Protect a key from further modifications (it be the values which can be modified through add(),
or the default value which can be modified through add_default()).

=head2 $config->file_read($file)

Read configuration data from a given file. The file is interpreted as a set of key/value pairs.
Pairs separated by a single '=' indicate mutable entries, while a double '==' means the entry
shall be protected and thus immutable.

=cut=
