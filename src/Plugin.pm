# slimrat - plugin infrastructure
#
# Copyright (c) 2008-2009 Přemek Vyhnal
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
#    Přemek Vyhnal <premysl.vyhnal gmail com> 
#

#
# Configuration
#

# Package name
package Plugin;

# Packages
use threads;
use threads::shared;
use WWW::Mechanize;

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Custom packages
use Log;
use Configuration;
use Proxy;

# Write nicely
use strict;
use warnings;

# Static hash for plugin registrations (should not get modified while running)
my %plugins;

# Shared hash with available resources
my %resources:shared;

# Static reference to the configuration object
my $config = new Configuration; # TODO: thread safe? Changes get shared?


#
# Object-oriented functionality
#

# Get an object
# Possible return values:
#  0 = object construction failed
#  -2 = resource allocation failed
#  an object = success
sub new {
	my $url = $_[1];
	my $mech = $_[2];
	
	fatal("cannot create plugin without configuration") unless ($config);

	if (my $plugin = get_package($url)) {
		# Resource handling
		fatal("plugin $plugin did not set resources correctly") if (!defined($resources{$plugin}));
		if ($resources{$plugin} != -1) {
			if ($resources{$plugin} < 1) {
				return -2;
			}
			$resources{$plugin}--;
			debug("lowering available resources for plugin $plugin to ", $resources{$plugin});
		}
		my $object = new $plugin ($config->section($plugin), $url, $mech);
		return $object;
	}
	return 0;
}

# Destructor
sub DESTROY {
	my ($self) = @_;
	
	# Resource handling
	my $plugin = ref($self);
		if ($resources{$plugin} != -1) {
		$resources{$plugin}++;
		debug("restoring available resources for plugin $plugin to ", $resources{$plugin});
	}
}


#
# Static functionality
#

# Configure the plugin producer
sub configure {
	my $complement = shift;
	$config->merge($complement);
	load_plugins();
}

# Register a plugin
sub register {
	$plugins{shift()}=(caller)[0];
}

# Provide instantes
sub provide {
	$resources{(caller)[0]} = shift;
}

# Get a plugin's name
sub get_package {
	(my $link) = @_;
	foreach my $re (keys %plugins){
		if($link =~ m#$re#i){
			return $plugins{$re};
		}
	}
	return "Direct";
}

# Load the plugins (dependancy check + execution, which triggers register())
sub load_plugins {

	# Let all plugins register themselves
	my @pluginfiles = glob "$RealBin/plugins/*.pm";
	LOOP: foreach my $plugin (@pluginfiles) {
		# Check for dependencies
		open(PLUGIN, $plugin);
		while (<PLUGIN>) {
			chomp;
			if ((/^\s*use (.+);/) and not (/strict/ || /warnings/)) {
				eval;
				if ($@) {
					my $module = $1;
					$module =~ s/ /, version >= /;
					$module =~ s/;$//;
					error("plugin '$plugin' shall not be used, due to unmet dependency $module");
					next LOOP;
				}
			}

		}
		close(PLUGIN);
		
		# Execute
		do $plugin;
		if($@) {
			error("\n".$@);
			fatal("plugin '$plugin' failed to load".($!?" ($!)":""));
		}
	}
	
	# Check and debug
	fatal("no plugins loaded") unless ((scalar keys %plugins) || (scalar grep /plugins\/Direct\.pm$/, keys %INC)); # Direct doesnt register, so it isnt in %plugins
	debug("loaded " . keys(%plugins) . " plugins (", join(", ", sort values %plugins), ")");

	scalar @pluginfiles; # Returns 0 (= failure to load) if no plugins present
}

# Return
1;


#
# Documentation
#

=head1 NAME 

Plugin

=head1 SYNOPSIS

  use Plugin;

  load_plugins();

  # To be done in a plugin
  register("TestPlugin", "http://www.TestSite.com");

  # Should result in "TestPlugin"
  my $pluginname = get_package("http://www.TestSite.com/download.php");

  # Instantiates an object from package TestPlugin
  my $plugin = Plugin::new("http://www.TestSite.com/download.php", $browser);

=head1 DESCRIPTION

Plugin manager, responsible for loading, checking, registering, and
dispatching plugins.

=head1 METHODS

=head2 Plugin::new($url, $ua)

Constructs a new object which is able to download the given URL. This object
is no instance of this package, but from a plugin which has been registered
to be able to process a given set of URLs.
$ua is the browser (LWP::UserAgent object) which shall be used to download
the file (upon the plugins get_data call).

=head2 Plugin::configure($config)

Merges the local base config with a set of user-defined configuration
values.

=head2 Plugin::register($regex)

Should be called by plugins, registers itself to get called when the $regex
matches. 

=head2 Plugin::get_package($url)

Get the package assigned with a given $url. This is for informational purposes, as
it does not instantiate an object of that type but merely does a lookup in the
internal datastructures.

=head2 Plugin::load_plugins()

Scans for plugins, checks their dependancies, and if met executes the plugin
file which subsequently should call Plugin::register() to get assigned with
a match of URLs.

=head1 AUTHOR

Přemek Vyhnal <premysl.vyhnal gmail com>
Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

