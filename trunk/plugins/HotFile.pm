#!/usr/bin/env perl
#
# slimrat - HotFile plugin
#
# Copyright (c) 2009 Yunnan
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
#    Yunnan <www.yunnan.tk>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

# Package name
package HotFile;

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
	return 1  if($mech->content() =~ m/Your download will begin in/);
	# TODO: detect 0-size reply HotFile returns upon dead links (and return 0 in other cases)
	return -1;
}

sub download {
	my $file = shift;
	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	$_ = $mech->content();
	
	# Extract primary wait timer
	my($wait1) = m#timerend\=d\.getTime\(\)\+([0-9]+);
  document\.getElementById\(\'dwltmr\'\)#;
	$wait1 = $wait1/1000;
	
	# Extract secondary wait timer
	my($wait2) = m#timerend\=d\.getTime\(\)\+([0-9]+);
  document\.getElementById\(\'dwltxt\'\)#;
	$wait2 = $wait2/1000;
	
	# Wait
	my($wait) = $wait1+$wait2;
        dwait($wait);
        
        # Click the button
	$mech->form_number(2); # free;
	$mech->submit_form();
	
	
	# Extract the download URL
	my $download = $mech->find_link( text => 'Click here to download' )->url();
	return error("plugin error (could not extract download link)") unless $download;
	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?hotfile.com");

1;

