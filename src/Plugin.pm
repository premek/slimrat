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
#    Přemek Vyhnal <premysl.vyhnal gmail com> 
#

#
# Configuration
#

# Package name
package Plugin;

# Packages
use WWW::Mechanize;

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Custom packages
use Log;
use Configuration;

# Write nicely
use strict;
use warnings;

# Static hash for plugins
my %plugins;

# Static reference to the configuration object
my $config = new Configuration;
$config->set_default("useragent", "Mozilla/5.0 (X11; U; Linux i686; en-US) Gecko/2009042316 Firefox/3.0.10");


my $mech = WWW::Mechanize->new(agent => $config->get("useragent"));
$mech->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
$mech->default_header('Accept-Language' => "en");



#
# Routines
#

# Get an object
sub new {
	my $url = $_[1];
	
	fatal("cannot create plugin without configuration") unless ($config);

	if(my $plugin = get_package($url)){
		my $object = new $plugin ($config->section($plugin), $url, $mech);
		return $object;
	}
	return 0;
}

# Configure the plugin producer
sub configure {
	my $complement = shift;
	$config->merge($complement);
	load_plugins();
}

# Register a plugin
sub register {
	my ($name,$re) = @_;
	$plugins{$re}=$name;
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

sub load_plugins {
	# load after Log and Configuration is initialized

	# Let all plugins register themselves
	my @pluginfiles = glob "$RealBin/plugins/*.pm";
	do $_ || do{system("perl -c $_"); fatal("plugin $_ failed to load ($!)")} foreach @pluginfiles;

	fatal("No plugins loaded") unless ((scalar keys %plugins) || (scalar grep /plugins\/Direct\.pm$/, keys %INC)); # Direct doesnt register, so it isnt in %plugins
	debug("loaded " . keys(%plugins) . " plugins (", join(", ", values %plugins), ")");

	scalar @pluginfiles; # Returns 0 (= failure to load) if no plugins present
}

1;
