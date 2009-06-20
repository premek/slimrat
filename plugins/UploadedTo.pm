# slimrat - UploadedTo plugin
#
# Copyright (c) 2009 Přemek Vyhnal
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
#    Přemek Vyhnal
#

# Package name
package UploadedTo;

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
		if ($res->decoded_content =~ m#File doesn't exist#) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

sub download {
	my $file = shift;

	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	$_ = $res->content."\n";


	if(my($minutes) = m#Or wait (\d+) minutes!#) { error("Your Free-Traffic is exceeded, wait $minutes minutes."); return 0; }

	# Extract url
	my ($download) = m#<form name="download_form" method="post" action="(.+?)">#;
	if (!$download) { error("plugin failure (could not find url)"); return 0; }

	# Extract filename
	my ($fname) = m/<title>(.+?) \.\.\./s;

	# Generate the download URL
	$download .= " \" --post-data \"download_submit=Free Download\"";
	if($fname) {$download .= " -O \"".$fname;} # works like wget http://... -O - > fname (overwrites the file!!!)
	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(uploaded.to/file|ul.to)/");

1;
