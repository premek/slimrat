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

# Packages
use Class::Struct;

# Write nicely
use strict;
use warnings;

# Custom packages
# NOTE: this module cannot include any custom package (it be Log.pm, Toolbox.pm, ...) as it is
#   used by almost any package and would cause circular dependancies. Also, including Log.pm
#   wouldn't help much as the verbosity etc. hasn't been initialised yet when the configuration
#   file is being parsed (debug() statements wouldn't matter). Instead, Perls internal
#   output routines are used (warn & die).
#   If there is a sensible way to include Log.pm, please change! It'd still be somewhat useful
#   to use functions like warning() and fatal() instead of warn and die.

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
		warn("attempt to overwrite existing key through initialisation");
		return 0;
	}
	
	my $item = new Item;
	$item->mutable(1);
	
	$self->{_items}->{$key} = $item;
	
	return 1;
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
	
	# Check if key already exists
	unless ($self->contains($key)) {
		$self->init($key);
	}
	
	# Update the default value
	$self->{_items}->{$key}->default($value);
}

# Get a value
sub get {	# Non-prototypes, as it can take 1 as well as 2 arguments
	my ($self, $key, $index) = @_;
	
	# Check if it contains the key (not present returns false)
	return 0 unless ($self->contains($key));
	
	# Index specified?
	if ($index) {
		if ($index == -1) {
			return $self->{_items}->{$key}->default;
		} else {
			return $self->{_items}->{$key}->values->[$index];
		}
	}
	
	# Index not specified
	else {
		if ($self->count($key) > 0) {
			return $self->{_items}->{$key}->values->[-1];
		} else {
			return $self->{_items}->{$key}->default;
		}
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
		warn("attempt to modify protected key \"$key\"");
		return 0;
	}
	
	# Modify value
	push(@{$self->{_items}->{$key}->values}, $value);
	return 1;
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

# Get the amount of stacked up items
sub count($$) {
	my ($self, $key) = @_;
	return -1 unless ($self->contains($key));
	return scalar(@{$self->{_items}->{$key}->values});
}

# Read a file
sub file_read($$) {
	my ($self, $file) = @_;
	my $prepend = "";	# Used for section seperation
	open(READ, $file) || die("could not open configuration file \"$file\"");
	while (<READ>) {
		chomp;
		
		# Skip comments, and leading & trailing spaces
		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		
		# Get the key/value pair
		if (my($key, $separator, $value) = /^(.+?)\s*(=+)\s*(.+?)$/) {		# The extra "?" makes perl prefer a shorter match (to avoid "\w " keys)

			#replace '~' with HOME of user who started slimrat
			$value =~ s#^~/#$ENV{'HOME'}/#;
			
			if ($key =~ m/(:)/) {
				warn("ignored configuration entry due to protected string in key (\"$1\")");
			} else {
				$self->add($prepend.$key, $value);
				$self->protect($prepend.$key) if (length($separator) >= 2);
			}
		}
		
		# Get section identifier
		elsif (/^\[(.+)\]$/) {
			my $section = lc($1);
			if ($section =~ m/^\w+$/) {
				$prepend = "$section:";
			} else {
				warn("ignored non-alphanumeric subsection entry");
			}
		}
		
		# Invalid entry
		else {
			warn("ignored invalid configuration entry \"$_\"");
		}
	}
	close(READ);
}

# Return a section
sub section($$) {
	my ($self, $section) = @_;
	$section = lc($section);
	
	# Extract subsection
	my $config_section = new Configuration;
	foreach my $key (keys %{$self->{_items}}) {
		if ($key =~ m/^$section:(.+)$/) {
			$config_section->{_items}->{substr($key, length($section)+1)} = $self->{_items}->{$key};
		}
	}
	
	return $config_section;
}

# Merge two configuration objects
sub merge($$) {
	my ($self, $complement) = @_;
	
	# Process all keys and update the complement
	foreach my $key (keys %{$self->{_items}}) {
		warn("base configuration object should not contain actual values, only defaults") if ($self->count($key) > 0);
		$complement->add_default($key, $self->get($key, -1));
	}
	
	# Update self
	$self->{_items} = $complement->{_items};
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

Adds a new item into the configuration, with $value as default value. This happens
always, even when the key has been marked as protected.

=head2 $config->add($key, $value)

Add a value to a specific key in the configuration. This is kept separated from the
default value, so one can still access the default value (and all previousely entered
values!) after adding a new value through this routine.
If nonexistant, the item gets created, by default mutable with "undef" as default value.

=head2 $config->count($key)

Get the amount of saved values for a specific key. This excludes the default value, and only
lists manually added values (through add(), or indirectly through file_read()).

=head2 $config->get($key)

Return the value for a specific key. Returns 0 if not found, and if found but no values
are found it returns the default value (which is "undef" if not specified).

=head2 $config->get($key, $index)

This returns a specific value, which can be used in case of multiple values corresponding
with a single key. Use the count() function to know the amount of values.
Special index -1 returns the default value.

=head2 $config->contains($key)

Check whether a specific key has been entered in the configuration (albeit by default
or customized value).

=head2 $config->protect($key)

Protect the values of a key from further modification. The default value always remains
mutable.

=head2 $config->file_read($file)

Read configuration data from a given file. The file is interpreted as a set of key/value pairs.
Pairs separated by a single '=' indicate mutable entries, while a double '==' means the entry
shall be protected and thus immutable.

=head2 $config->section($section)

Returns a new Configuration object, only containing key/value pairs listed in the given section.
This can be used to seperate the configuration of several parts, in the case of slimrat e.g.
preventing a malicious plugin to access data (e.g. credentials) of other plugins. Keys are
internally identified by the key and a section preposition, which makes it possible to use
identical keys in different sections. The internally used seperation of preposition and key
(a ":") is protected in order to avoid a security leak.
Be warned though that the section Configuration object only contains references to the actual
entries, so modifying the section object _will_ modify the main configuration object too (unless
protected offcourse).
NOTE: section entries are case-insensitive.

=head2 $config->merge($complement)

Merges two Configuration objects. This is especially usefull in combination with the section()
routine: a package/objects creates a Configuration object with some default entries at
BEGIN/construction, but gets passed another Configuration object with some user-defined
entries. The merge function will read all values in the $self object (the one with the
default values), and update those values in the passed $complement object. This in order
to update the main Configuration object, as the complement only contains references.
  use Configuration;
  
  # A package creates an initial Configuration object (e.g. at construction)
  my $config_package = new Configuration;
  $config_package->add_default("foo", "bar");
  
  # The main application reads the user defined values (from file, or manually, ...)
  my $config_main = new Configuration;
  $config_main->file_read("/etc/configuration");
  
  # The package receives the configuration entries it is interested in, and merges them
  # with the existing default values
  $config_package->merge($config_main->section("package"));
  
  # The package configuration object shall now contain all user specified entries, with
  # preserved default values. It'll also contain default values for objects not specified
  # by the user.
  # The main configuration object will contain all user-defined values, with updated
  # default values. It'll however NOT contain entries which have been specified by the
  # package (add_default) but not by the user (see NOTE).  
NOTE: when the package configures a default value which hasn't been user-defined, that value
will NOT be saved in the main Configuration object. This because it'd need the package to have
access to the main configuration object, which would undo the configuration separation
introduced by the sections.

=cut=
