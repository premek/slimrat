# slimrat - ShareBase plugin
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
package ShareBase;

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
	return -1 if($mech->content() =~ m/The download doesnt exist/);
	return -1 if($mech->content() =~ m/Der Download existiert nicht/);
	return -1 if($mech->content() =~ m/Upload Now !/);
	return 1  if($mech->content() =~ m/Download Now !/);
	return 0;
}

sub download {
	my $file = shift;
	
	# Get the primary page
	my $res = $mech->get($file);
	return error("plugin failure (page 1 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Click the button
	$_ = $res->content."\n";
	my ($asi) = m/name="asi" value="([^\"]+)">/s;
	
	
	$res = $mech->post($file, [ 'asi' => $asi , $asi => 'Download Now !' ] );
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	$_ = $res->content."\n";
	
	# Process the secondary page
	my $counter = 0;
	while (1) {
		my $wait;
		$counter = $counter + 1;
		if( ($wait) = m/Du musst noch <strong>([0-9]+)min/ ) {
		    info("reached the download limit for free-users (300 MB)");
		    dwait(($wait+1)*60);
		    $res = $mech->reload();
		    $_ = $res->content."\n";
		} elsif( $mech->uri() =~ $file ) {
		    info("something wrong, waiting 60 sec");
		    dwait(60);
		} else {
		    last;
		}
		if($counter > 5) {
			error("plugin failure (loop error)"); die();
		}
	}
	
	my $download = $mech->uri();
	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?sharebase.to");

1;
