# slimrat - Rapidshare plugin
#
# Copyright (c) 2008-2009 Přemek Vyhnal
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
#    Přemek Vyhnal <premysl.vyhnal gmail com>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

# Package name
package Rapidshare;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

# Maximum wait interval (in minutes)
my $wait_max = 2;

my $mech = WWW::Mechanize->new('agent'=>$useragent);

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/form id="ff" action/) {
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
	return error("plugin failure (page 1 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Click the "Free" button
	$mech->form_number(1);
	$res = $mech->submit_form();
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n"; 

		if(m/reached the download limit for free-users/) {
			($wait) = m/Or try again in about (\d+) minutes/sm;
			info("reached the download limit for free-users");			
		} elsif(($wait) = m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
			info("currently a lot of users are downloading files");
		} elsif(($wait) = m/no available slots for free users\. Unfortunately you will have to wait (\d+) minutes/) {
			info("no available slots for free users");

		} elsif(m/already downloading a file/) {
			info("already downloading a file");
			$wait = 60;
		} else {
			last;
		}
		
		if ($wait > $wait_max) {
			debug("should wait $wait minutes, interval-check in $wait_max minutes");
			$wait = $wait_max;
		}
		dwait($wait*60);
		$res = $mech->reload();
	}

	# Extract the download URL
	my ($download, $wait) = m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm;
	return error("plugin error (could not extract download link)") unless $download;
	dwait($wait);

	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?rapidshare.com");

1;
