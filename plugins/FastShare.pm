#!/usr/bin/env perl
#
# slimrat - DepositFiles plugin
#
# Copyright (c) 2009 Yunnan
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
#    Yunnan <www.yunnan.tk>
#

# Package name
package FastShare;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent' => $useragent );

# return - as usual
#   1: ok
#  -1: dead
#   0: don't know

sub check {
	$mech->get(shift);
	return -1 if($mech->content() =~ m/No filename specified or the file has been deleted!/);
	return 1  if($mech->content() =~ m/klicken sie bitte auf Download!/);
	return 0;
}

sub download {
	my $file = shift;
	my $res = $mech->get($file);
	if (!$res->is_success) { error("plugin failure (", $res->status_line, ")"); return 0;}
	else {
		$mech->form_number(0);
		$mech->submit_form();
		$_ = $mech->content;
		my ($download) = m/<br>Link: <a href=([^>]+)><b>/s;
		return $download;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?fastshare.org");

1;
