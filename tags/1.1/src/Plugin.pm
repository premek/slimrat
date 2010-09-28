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
use LWP::Simple;
use File::Basename;

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

# Static hashes
my %plugins;
my %details;

# Shared hashes
my %resources:shared;
my $per_plugin = "unaltered";

# Static reference for the global configuration object
my $config_global = new Configuration;

# Base configuration
my $config = new Configuration;
$config->section("all")->set_default("retry_count", 5);
$config->section("all")->set_default("retry_timer", 60);


#
# Object-oriented functionality
#

# Get an object
# Possible return values:
#  0 = object construction failed
#  an object = success
sub new {
	my ($class, $url, $mech, $no_lock) = @_;
	$no_lock = 0 unless defined($no_lock);
	
	fatal("cannot create plugin without configuration") unless ($config_global);

	if (my $plugin = get_package($url)) {
		# Resource handling
		{
			lock(%resources);
			fatal("plugin $plugin did not set resources correctly") if (!defined($resources{$plugin}));
			if ($resources{$plugin} >= 0) {
				if ($resources{$plugin} == 0) {
					debug("insufficient resources available");
					if ($no_lock) {
						return -1;
					} else {
						cond_wait(%resources) until $resources{$plugin} > 0;
					}
				}
				$resources{$plugin}--;
				debug("lowering available resources for plugin $plugin to ", $resources{$plugin});
			}
		}
		
		# Construction
		my $object = new $plugin ($config_global->section($plugin), $url, $mech);
		return $object;
	}
	return 0;
}

# Destructor
sub DESTROY {
	my ($self) = @_;
	
	# Resource handling
	my $plugin = ref($self);
	lock(%resources);
	if ($resources{$plugin} >= 0) {
		$resources{$plugin}++;
		cond_signal(%resources);
		debug("restoring available resources for plugin $plugin to ", $resources{$plugin});
	}
}

# Return code
sub code {
	my ($self) = @_;
	return $self->{MECH}->status();
}

# Reload the page
sub reload {
	my ($self) = @_;
	my $res = $self->{MECH}->reload();
	die("error reloading page, ", $self->{MECH}->status()) unless ($self->{MECH}->success());
	dump_add(data => $self->{MECH}->content());
	return $res;
}

# Get an URL
sub fetch($) {
	my ($self, $url) = @_;
	$url = $self->{URL} unless $url;
	my $res = $self->{MECH}->get($url);
	die("error reloading '$url', ", $self->{MECH}->status()) unless ($self->{MECH}->success());
	dump_add(data => $self->{MECH}->content());
	return $res;
}

# Get data
sub get_data {
	# Input data (the stuff we need)
	my $self = shift;
	
	# Fetch primary page
	$self->fetch();
	
	# Main loop
	while (1) {
		# Iterate
		my $rv = $self->get_data_loop(@_);
		
		# Check if the plugin actually did something
		if (!defined($rv)) {
			die("plugin could not match any action");
		}
		
		# Check if HTTP::Response
		elsif (ref($rv) eq "HTTP::Response") {
			return $rv;
		}
		
		# Normal loop exit, please retry
		elsif ($rv == 1) {
			next;
		}
		
		# Unknown RV
		else {
			warning("plugin returned unknown value of type ", ref($rv));
			die("todo");
		}
	}	
}


#
# Static functionality
#

# Configure the plugin producer
sub configure {
	my $complement = shift;
	$config_global->merge($complement);
	$config->merge($config_global->section("plugin"));
	
	# Load plugins
	load("$RealBin/plugins");
	execute();
	fatal("no plugins loaded") unless ((scalar keys %plugins) || (scalar grep /plugins\/Direct\.pm$/, keys %INC)); # Direct doesnt register, so it isnt in %plugins
	debug("loaded " . keys(%plugins) . " plugins (", join(", ", sort values %plugins), ")");
}

# Register a plugin
sub register {
	$plugins{shift()}=(caller)[0];
}

# Provide instantes
sub provide {
	lock(%resources);
	$resources{(caller)[0]} = shift;
	cond_broadcast(%resources);
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

# Load the plugins (dependancy check and other pre-parsing code)
sub load {
	my $folder = shift;
	
	# Process all plugins
	my $counter = 0;
	my @pluginfiles = <$folder/*.pm>;
	LOOP: foreach my $plugin (@pluginfiles) {
		# Quick parse
		my %plugin_info = ();
		open(PLUGIN, $plugin);
		while (<PLUGIN>) {
			chomp;
			
			# Dependancy checking
			if ((m/^\s*use (.+);/) and not (m/strict/ || m/warnings/)) {
				eval;
				if ($@) {
					my $module = $1;
					$module =~ s/ /, version >= /;
					$module =~ s/;$//;
					error("plugin '$plugin' shall not be used, due to unmet dependency $module");
					next LOOP;
				}
			}
			
			# Parse special instructions
			elsif (m/^##\s*(\w+)\s+(.+)/) {
				$plugin_info{$1} = $2;			
			}
		} 
		close(PLUGIN);
		$plugin_info{PATH} = $plugin;
		
		# Check if plugin isn't registered yet
		if (defined($details{basename($plugin)})) {
			error("plugin '", basename($plugin), "' loaded twice");
			next;
		} else {
			$details{basename($plugin)} = \%plugin_info;
		}
		
		$counter++;
	}
	
	return $counter;
}

# Execute all plugins (which effectively includes them in the active slimrat session)
sub execute {
	foreach my $plugin (keys %details ) {
		my $status = do $details{$plugin}{PATH};
		if (!$status) {
			if ($@) {
				fatal("failed to parse plugin '$plugin' ($@)");
			}
			elsif ($!) {
				fatal("failed to compile plugin '$plugin' ($!)");
			}
			else {
				fatal("failed to load plugin '$plugin'");
			}
			next;
		}
	}
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

=head2 Plugin::new($url, $mech, $no_lock)

Constructs a new object which is able to download the given URL. This object
is no instance of this package, but from a plugin which has been registered
to be able to process a given set of URLs.
$mech is the browser (WWW::Mechanize object) which shall be used to download
the file (upon the plugins get_data call).
When $no_lock is set, the construction return -1 when there are no resources
available, instead of lock automatically.

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

