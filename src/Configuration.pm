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
		value		=>	'$',
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
	
	# Add at right spot (self or parent)
	if ($self->{_parent}) {
		$self->{_parent}->init($self->{_section} . ":" . $key);
		$self->{_items}->{$key} = $self->{_parent}->{_items}->{$self->{_section} . ":" . $key};
	} else {
		$self->{_items}->{$key} = $item;
	}
	
	return 1;
}


#
# Routines
#

# Constructor
sub new {
	my $self = {
		_items		=>	{},	# Anonymous hash
		_parent		=>	undef,
		_section	=>	undef,
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
sub set_default($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if key already exists
	unless ($self->contains($key)) {
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
	
	# Return value or default
	if (defined $self->{_items}->{$key}->value) {
		return $self->{_items}->{$key}->value;
	} else {
		return $self->{_items}->{$key}->default;
	}
}

# Get the default value
sub get_default($$) {
	my ($self, $key) = @_;
	
	# Check if it contains the key (not present returns false)
	return 0 unless ($self->contains($key));
	
	# Return default
	return $self->{_items}->{$key}->default;
}

# Set a value
sub set($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if contains
	if (!$self->contains($key)) {
		$self->init($key);
	}
	
	# Check if mutable
	if (! $self->{_items}->{$key}->mutable) {
		warn("attempt to modify protected key '$key'");
		return 0;
	}
	
	# Modify value
	$self->{_items}->{$key}->value($value);
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

# Read a file
sub file_read($$) {
	my ($self, $file) = @_;
	my $prepend = "";	# Used for section seperation
	open(READ, $file) || die("could not open configuration file '$file'");
	while (<READ>) {
		chomp;
		
		# Skip comments, and leading & trailing spaces
		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		
		# Get the key/value pair
		if (my($key, $separator, $value) = /^(.+?)\s*(=+)\s*(.+?)$/) {		# The extra "?" makes perl prefer a shorter match (to avoid "\w " keys)

			# Replace '~' with HOME of user who started slimrat
			$value =~ s#^~/#$ENV{'HOME'}/#;
			
			# Substitute negatively connoted values
			$value =~ s/^(off|none|disabled|false)$/0/i;
			
			if ($key =~ m/(:)/) {
				warn("ignored configuration entry due to protected string in key ('$1')");
			} else {
				$self->set($prepend.$key, $value);
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
			warn("ignored invalid configuration entry '$_'");
		}
	}
	close(READ);
}

# Return a section
sub section($$) {
	my ($self, $section) = @_;
	$section = lc($section);
	
	# Prohibit double (or more) hiërarchies
	return error("can only split section from top-level configuration object") if ($self->{_section});
	
	# Extract subsection
	my $config_section = new Configuration;
	foreach my $key (keys %{$self->{_items}}) {
		if ($key =~ m/^$section:(.+)$/) {
			$config_section->{_items}->{substr($key, length($section)+1)} = $self->{_items}->{$key};
		}
	}
	
	# Give the section parent access
	$config_section->{_parent} = $self;
	$config_section->{_section} = $section;
	
	return $config_section;
}

# Merge two configuration objects
sub merge($$) {
	my ($self, $complement) = @_;
	
	# Process all keys and update the complement
	foreach my $key (keys %{$self->{_items}}) {
		warn("merge call only copies defaults") if (defined $self->{_items}->{$key}->value);
		$complement->set_default($key, $self->get_default($key));
	}
	
	# Update self
	$self->{_items} = $complement->{_items};
}

# Save a value to a configuration file
sub save($$) {
	my ($self, $key, $current) = @_;	
	return error("cannot save undefined key '$key'") if (!$self->contains($key));
	my $temp = $current.".temp";
	
	# Case 1: configuration file does not exist, create new one
	if (! -f $current) {
		open(WRITE, ">$current");
		print WRITE "[" . $self->{_section} . "]\n" if (defined $self->{_section});
		print WRITE $key . " = " . $self->get($key);
		close(WRITE);
	}
	
	# Case 2: configuration file exists, re-read
	else {
		open(READ, "<$current");
		open(WRITE, ">$temp");
		
		# Look for a match and update it
		my $temp_section;
		while (<READ>) {
			chomp;
		
			# Get the key/value pair
			if (my($temp_key) = /^(.+?)\s*=+\s*.+?$/) {
				if ($key eq $temp_key) {
					if (  (defined $self->{_section} && defined $temp_section && $self->{_section} eq $temp_section)
					   || (!defined $self->{_section} && !defined $temp_section) ) {
						print WRITE $key . " = " . $self->get($key) . "\n";
						last;
					}				
				}
			}
		
			# Get section identifier
			elsif (/^\[(.+)\]$/) {
				$temp_section = lc($1);
			}
						
			print WRITE "$_\n";
		}
		
		# No match found, prepend or append key
		if (eof(READ)) {
			if (defined $self->{_section}) {
				print WRITE "\n[" . $self->{_section} . "]\n";
				print WRITE $key . " = " . $self->get($key) . "\n";
			} else {
				# Prepend, when no section defined
				seek(WRITE, 0, 0);
				seek(READ, 0, 0);
				print WRITE $key . " = " . $self->get($key) . "\n";
				print WRITE while (<READ>);
					
			}
		}
		
		# Match found, just copy rest of the file
		else {
			print WRITE while (<READ>);
		}
		
		# Clean up
		close(READ);
		close(WRITE);
		unlink $current;
		rename $temp, $current;	
	}
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

=head2 $config->set_default($key, $value)

Adds a new item into the configuration, with $value as default value. This happens
always, even when the key has been marked as protected. Any previously entered
values do not get overwritten, which makes it possible to enter or re-enter a
default value after actual values has been entered.

=head2 $config->set($key, $value)

Set a key to a given value. This is separated from the default value, which can still
be accessed with the default() call.

=head2 $config->get($key)

Return the value for a specific key. Returns 0 if not found, and if found but no values
are found it returns the default value (which is "undef" if not specified).

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
Values in the section object are references to the main object, adjusting them will this
adjust the main object.
NOTE: section entries are case-insensitive.
IMPORTANT NOTE: do _not_ use the ":" token to get/set values within a section, _always_ use
the section("foo")->get/set construction.

=head2 $config->merge($complement)

This function merges two Configuration objects. This is intent to merge an object with
default values, with one containing the user-defined values, correctly filling the gaps.
As the add_default function does not overwrite user-defined values, you should normally
never need this function, as you can apply defaults upon the configuration object
containing the user-defined values. E.g., plugins get an configuration object passed
in the constructor, in which default values get applied.

When however the configuration object is needed before user-defined values get passed (e.g.
a static package, see Log.pm), there will be a pre-existent configuration object containing
the default values. Upon configuration, the merge() call can be used to merge that object
with the passed one containing user-defined values. Again, this should be rarely used, and when
needed check the usage in Log.pm.
  use Configuration;
  
  # A package creates an initial Configuration object (e.g. at BEGIN block)
  my $config_package = new Configuration;
  $config_package->set_default("foo", "bar");
  
  # The main application reads the user defined values (from file, or manually, ...)
  my $config_main = new Configuration;
  $config_main->file_read("/etc/configuration");
  
  # The package receives the configuration entries it is interested in, and merges them
  # with the existing default values
  $config_package->merge($config_main->section("package"));

=head2 $config->save($key, $file)

This function will make a configuration entry persistent, by saving it into a given file.
That file gets parsed, and when possible a key will get updated. When the key doesn't
exist in the file yet, it will get appended (when within a subsection) or prepended (when
not within a subsection). When the file does not exist, a new one will get created.

=cut=
