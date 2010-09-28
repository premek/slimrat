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
use threads;
use threads::shared;
use File::Spec;

# Write nicely
use strict;
use warnings;


#
# Static functionality
#

# Quit the package
sub quit() {
}


#
# Object-oriented functionality
#

# Create a new item (internally used)
sub init($$) {
	my ($self, $key) = @_;
	
	if ($self->defines($key)) {
		warn("attempt to overwrite existing key through initialisation");
		return 0;
	}
	
	# Add at right spot (self or parent)
	if ($self->{parent}) {
		$self->{parent}->init($self->{section} . ":" . $key);
		$self->{items}->{$key} = $self->{parent}->{items}->{$self->{section} . ":" . $key};
	} else {
		share($self->{items}->{$key});
		$self->{items}->{$key} = &share({});
		$self->{items}->{$key}->{mutable} = 1;
		$self->{items}->{$key}->{default} = undef;
		$self->{items}->{$key}->{value} = undef;
	}
	
	return 1;
}

# Constructor
sub new {
	# Object data container (shared hash)
	my $self;
	share($self);
	$self = &share({});
	
	# Items (shared hash)
	share($self->{items});
	$self->{items} = &share({});
	
	# Parent configuration object (shared reference)
	$self->{parent} = undef;
	
	# Subsection
	$self->{section} = undef;
	
	return bless($self, 'Configuration');
}

# Check if the configuration contains a specific key definition
sub defines($$) {
	my ($self, $key) = @_;
	die("no key specified") unless $key;
	if (exists $self->{items}->{$key}) {
		return 1;
	} else {
		return 0;
	}
}

# Add a default value
sub set_default($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if key already exists
	unless ($self->defines($key)) {
		$self->init($key);
	}
	
	# Update the default value
	$self->{items}->{$key}->{default} = $value;
}

# Get the default value
sub get_default($$) {
	my ($self, $key) = @_;
	
	if ($self->defines($key)) {
		return $self->{items}->{$key}->{default};
	}
	return undef;
}

# Get the actual value (ie. do not return default if not defined)
sub get_value($$) {
	my ($self, $key) = @_;
	
	if ($self->defines($key)) {
		return $self->{items}->{$key}->{value};
	}
	return undef;
}

# Get a value
sub get($$) {
	my ($self, $key) = @_;
	
	# Check if it contains the key (not present returns false)
	if (! $self->defines($key)) {
		warn("access to undefined key '$key'");
		return undef;
	}
	
	# Return value or default
	if (defined(my $value = $self->get_value($key))) {
		return $value;
	} elsif (defined(my $default = $self->get_default($key))) {
		return $default;
	}
	return undef;
}

# Set a value
sub set($$$) {
	my ($self, $key, $value) = @_;
	
	# Check if contains
	if (!$self->defines($key)) {
		$self->init($key);
	}
	
	# Check if mutable
	if (! $self->{items}->{$key}->{mutable}) {
		warn("attempt to modify protected key '$key'");
		return 0;
	}
	
	# Modify value
	$self->{items}->{$key}->{value} = $value;
	return 1;
}

# Protect an item
sub protect($$) {
	my ($self, $key) = @_;
	if ($self->defines($key)) {
		$self->{items}->{$key}->{mutable} = 0;
		return 1;
	}
	warn("attempt to protect undefined key '$key'");
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
		if (my($key, $separator, $value) = /^(.+?)\s*(=+)\s*(.*?)$/) {		# The extra "?" makes perl prefer a shorter match (to avoid "\w " keys)

			# Replace '~' with HOME of user who started slimrat
			$value =~ s#^~/#$ENV{'HOME'}/#;
			
			# Substitute negatively connoted values
			$value =~ s/^(|off|none|disabled|false|no)$/0/i;
			
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
	return error("can only split section from top-level configuration object") if ($self->{section});
	
	# Extract subsection
	my $configsection = new Configuration;
	foreach my $key (keys %{$self->{items}}) {
		if ($key =~ m/^$section:(.+)$/) {
			$configsection->{items}->{substr($key, length($section)+1)} = $self->{items}->{$key};
		}
	}
	
	# Give the section parent access
	$configsection->{parent} = $self;
	$configsection->{section} = $section;
	
	return $configsection;
}

# Merge two configuration objects
sub merge($$) {
	my ($self, $complement) = @_;
	
	# Process all keys and update the complement
	foreach my $key (keys %{$self->{items}}) {
		# We must manually init, or "undef" default values won't merge properly
		$complement->init($key) unless ($complement->defines($key));		
		
		if (defined(my $default = $self->get_default($key))) {
			warn("merge overwrites default value of key $key") if (defined($complement->get_default($key)));
			$complement->set_default($key, $default);
		}		
		if (defined(my $value = $self->get_value($key))) {
			warn("merge overwrites value of key $key") if (defined($complement->get_value($key)));
			$complement->set($key, $value);
		}		
	}
	
	# Update self
	$self->{items} = $complement->{items};
}

# Save a value to a configuration file
sub save($$) {
	my ($self, $key, $current) = @_;
	return error("cannot save undefined key '$key'") unless ($self->defines($key));
	my $temp = $current.".temp";
	
	# Case 1: configuration file does not exist, create new one
	if (! -f $current) {
		open(WRITE, ">$current");
		print WRITE "[" . $self->{section} . "]\n" if (defined $self->{section});
		print WRITE $key . " = " . $self->get($key);
		close(WRITE);
	}
	
	# Case 2: configuration file exists, re-read
	else {
		open(READ, "<$current");
		open(WRITE, ">$temp");
		
		# Look for a match and update it
		my $tempsection;
		while (<READ>) {
			chomp;
		
			# Get the key/value pair
			if (my($temp_key) = /^(.+?)\s*=+\s*.+?$/) {
				if ($key eq $temp_key) {
					if (  (defined $self->{section} && defined $tempsection && $self->{section} eq $tempsection)
					   || (!defined $self->{section} && !defined $tempsection) ) {
						print WRITE $key . " = " . $self->get($key) . "\n";
						last;
					}				
				}
			}
		
			# Get section identifier
			elsif (/^\[(.+)\]$/) {
				$tempsection = lc($1);
			}
						
			print WRITE "$_\n";
		}
		
		# No match found, prepend or append key
		if (eof(READ)) {
			if (defined $self->{section}) {
				print WRITE "\n[" . $self->{section} . "]\n";
				print WRITE $key . " = " . $self->get($key) . "\n";
			} else {
				# Prepend before first section, when not defined
				seek(WRITE, 0, 0);
				seek(READ, 0, 0);
				my $written = 0;
				while (<READ>) {
					if (!$written && /^\[(.+)\]$/) {
						print WRITE $key . " = " . $self->get($key) . "\n";
						$written = 1;
					}
					print WRITE;
				}
				print WRITE $key . " = " . $self->get($key) . "\n" unless ($written);					
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

# Convert a path to absolute setting
sub path_abs {
	my $self = shift;
	while (my $key = shift) {
		if (my $value = $self->get_value($key)) {	# No need to update default values
			return error("cannot convert immutable key") unless $self->{items}->{$key}->{mutable};
			$self->set($key, File::Spec->rel2abs($value));
		}
	}
}

# Return
1;


#
# Documentation
#

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

Return the value for a specific key. If not value specified, returns the default value.
Returns undef if no default value specified either.

NOTE: recently behaviour of this function has altered, there it now supports and correctly
returns values which Perl evaluates to FALSE. When checking if a configuration value
is present, please use defined() now instead of regular boolean testing.

=head2 $config->get_default($key)

Returns the default value, or undef if not specified.

=head2 $config->get_value($key)

Returns the value of the key, or undef if not specified. Does not return the default
value.

=head2 $config->defines($key)

Check whether a specific key has been entered in the configuration (albeit by default
or customized value). This does not look at the value itself, which can e.g. be 'undef'.

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
needed check the usage in Log.pm or other packages.
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

=head2 $config->path_abs(@keys)

Converts the paths saved in the given keys (if available) from a relative to an absolute setting.
Can be used before daemonisation.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

