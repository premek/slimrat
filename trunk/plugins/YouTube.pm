#!/usr/bin/env perl
#
# slimrat - main GUI script
#
# Copyright (c) 2008 Přemek Vyhnal
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
# Thanks to:
#    Bartłomiej Palmowski
#

# Package name
package YouTube;

# Modules
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent'=>$useragent );

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/<div class="errorBox">/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

sub download {
	# Extract data from SWF loading script
	my ($v, $t) = $mech->get(shift)->decoded_content =~ /swfArgs.*"video_id"\s*:\s*"(.*?)".*"t"\s*:\s*"(.*?)".*/;
	return "http://www.youtube.com/get_video?video_id=$v&t=$t";
}

Plugin::register(__PACKAGE__,"^[^/]+//[^.]*\.?youtube\.com/watch[?]v=.+");

1;
