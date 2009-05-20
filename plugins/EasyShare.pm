#!/usr/bin/env perl
#
# slimrat - Easy-Share plugin
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

# Package name
package EasyShare;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent'=>$useragent);

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/msg-err/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	# Get the page
	my $res = $mech->get($file);
	if (!$res->is_success) { error("plugin failure (", $res->status_line, ")"); return 0;}
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n"; 
		
		# Wait if the site requests to (not yet implemented)
		if(m/some error message/) {
			($wait) = m/extract some (\d+) minutes/sm;
		} else {
			last;
		}
		
		dwait($wait*60);
		$res = $mech->reload();
	}
	
	# Process the timer
	if (m/Seconds to wait: (\d+)/) {
		my $wait = $1;
		dwait($wait);
	} else {
		error("plugin failure (could not extract wait time)");
		return 0;
	}
	
	# Extract the code
	my $code;
	if (m/\/file_contents\/captcha_button\/(\d+)/) {
		$code = $1;
	} else {
		error("plugin failure (could not extract captcha code)");
		return 0;
	}
	
	# Get the second page
	$res = $mech->get('http://www.easy-share.com/c/' . $code);
	$_ = $res->decoded_content."\n";
	
	# Extract the download URL
	my $url;
	if (m/action=\"([^"]+)\" class=\"captcha\"/) {
		$url = $1;
	} else {
		error("plugin failure (could not extract download url)");
		return 0;
	}
	
	# Download $file by sending a POST to $url with id=$code && captcha=1

	return 0;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?easy-share.com");

1;
