#!/usr/bin/env perl
#
# slimrat - FastLoad plugin
#
# Copyright (c) 2008 Tomasz Gągor
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
#

# Package name
package FastLoad;

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
		if ($res->decoded_content =~ m/name="fid" value/) {
			return 1;
		} else {
			return -1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	my $res = $mech->get($file);
	if (!$res->is_success) { error("plugin failure (page 1 error, ", $res->status_line, ")"); return 0;}
	else {
		$_ = $res->content."\n";
		my ($fname) = m/<span style="font-color:grey; font-weight:normal; font-size:8pt;">(.+?)<\/span>/s;
		if (!$fname) { error("plugin failure (could not find file name)"); return 0;}
		my ($fid) = m/name="fid" value="(\w+)"/sm;
		if (!$fid) { error("plugin failure (could not find FID number)"); return 0;}
		my $download = "http://www.fast-load.net/download.php' --post-data 'fid=".$fid."' -O '".$fname;

		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?fast-load.net");

1;