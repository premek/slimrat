#!/usr/bin/env perl
#
# slimrat - MediaFire plugin
#
# Copyright (c) 2008 Tomasz Gągor
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
#    Tomasz Gągor <timor o2 pl>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

# Package name
package MediaFire;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent' => $useragent );

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/) {
			return 1;
		} else {
			return -1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	# Get the primary page
	my $res = $mech->get($file);
	return error("plugin failure (page 1 error", $res->status_line, ")") unless ($res->is_success);
	
	$_ = $res->decoded_content."\n";
	my ($qk,$pk,$r) = m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/sm;
	if(!$qk) {
		error("plugin failure (page 1 error, file doesn't exist or was removed)");
		return 0;
	}
	
	# Get the secondary page
	$res = $mech->get("http://www.mediafire.com/dynamic/download.php?qk=$qk&pk=$pk&r=$r");
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
		
	$_ = $res->decoded_content."\n";
	
	# Extract download parameters
	my ($mL,$mH,$mY) = m/var mL='(.+?)';var mH='(\w+)';var mY='(.+?)';.*/sm;
	my ($varname) = m#href=\\"http://"\+mL\+'/'\+ (\w+) \+'g/'\+mH\+'/'\+mY\+'"#sm;
	my ($var) = m#var $varname = '(\w+)';#sm;
	return error("plugin error (could not extract download parameters)") unless ($mL && $mH && $mY && $var);
	
	# Generate the download URL
	my $download = "http://$mL/${var}g/$mH/$mY";
	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?mediafire.com");

1;
