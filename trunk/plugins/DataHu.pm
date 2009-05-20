#!/usr/bin/env perl
#
# slimrat - DataHU plugin
#
# Copyright (c) 2009 Gabor Bognar
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
#    Gabor Bognar <wade at wade dot hu>
#

package DataHu;
use Toolbox;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use WWW::Mechanize;
use strict;
use warnings;
use Data::Dumper;

my $mech = WWW::Mechanize->new('agent'=>$useragent);

# return
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $file = shift;
	$mech->get($file);
	$_ = $mech->content();
	return -1 if(m#error_box#);
	return 1;
}

sub download {
	my $file = shift;

	my $res = $mech->get($file);
	if (!$res->is_success) { print RED "Plugin error: ".$res->status_line."\n\n"; return 0;}

	$_ = $res->decoded_content."\n"; 
	my $ok = 0;
	while(!$ok){
		my $wait;


		if(m#kell:#) {
			$ok=0;
			($wait) = m#<div id="counter" class="countdown">(\d+)</div>#sm;
			dwait($wait);
			$res = $mech->reload();
			$_ = $res->decoded_content."\n"; 
		} else {
			$ok=1;
		}
	}

	my ($download) = m/class="download_it"><a href="(.*)" onmousedown/sm;
	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?data.hu");

1;
