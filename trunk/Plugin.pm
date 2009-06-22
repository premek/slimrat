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

use File::Basename;
my ($root) = dirname($INC{'Plugin.pm'});

# Modules
use Log;

# Export functionality
use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw();

# Write nicely
use strict;
use warnings;

# Static hash for plugins
my %plugins;


#
# Routines
#

# Register a plugin
sub register {
	my ($name,$re) = @_;
	$plugins{$re}=$name;
}

# Get a plugin's name
sub get_name {
	(my $link) = @_;
	foreach my $re (keys %plugins){
		if($link =~ m#$re#i){
			return $plugins{$re};
		}
	}
	return "Direct";
}


#
# "Main"
#

# Let all plugins register themselves
my @pluginfiles = glob "$root/plugins/*.pm";
do $_ || do{system("perl -c $_"); fatal("plugin $_ failed to load ($!)")} foreach @pluginfiles;

# Print some debug message (yeah the regular way, couldn't port existing print & $, madness to something Log::debug() worthy)
my $string;
$string .= $_.", " foreach (values %plugins);
debug("loaded " . keys(%plugins) . " plugins (", substr($string, 0, length($string)-2), ")");

scalar @pluginfiles; # Returns 0 (= failure to load) if no plugins present
