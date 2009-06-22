# slimrat - Leteckaposta plugin
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

# Package name
package Leteckaposta;

# Modules
use Log;
use Toolbox;
use LWP::UserAgent;

# Write nicely
use strict;
use warnings;

my $ua = LWP::UserAgent->new;
$ua->agent($useragent);



sub check {
	my $res = $ua->get(shift);
	return -1 unless ($res->is_success);
	return -1 if $res->decoded_content =~ m/Soubor neexistuje/;
	return 1 if $res->decoded_content =~ m/href='([^']+)' class='download-link'/;
}

sub download {
	my $file = shift;

	my $res = $ua->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	# Extract the download URL
	my ($download, $filename) = $res->decoded_content =~ m#href='([^']+)' class='download-link'>(.+?)</a>#;
	return error("plugin error (could not extract download link)") unless $download;
	$download = "http://leteckaposta.cz$download";
	$download .= "\" -O \"".$filename if ($filename);
	return $download;
}

Plugin::register(__PACKAGE__, "^[^/]+//(?:www.)?leteckaposta.cz");

1;
