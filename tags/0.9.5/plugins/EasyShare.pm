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

	# Get the primary page
	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	# Process the resulting page
	my $code;
	while (1) {
		$_ = $res->decoded_content."\n";
		
		# Wait timer?
		if (m/Seconds to wait: (\d+)/) {
			# Wait
			dwait($1);
	
			# Extract the captcha code
			($code) = m/\/file_contents\/captcha_button\/(\d+)/;
			return error("plugin failure (could not extract captcha code)") unless $code;
			
			$res = $mech->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Download without wait?
		if (m/http:\/\/www.easy-share.com\/c\/(\d+)/) {
			$code = $1;
			$res = $mech->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Wait if the site requests to (not yet implemented)
		if(m/some error message/) {
			my ($wait) = m/extract some (\d+) minutes/sm;		
			return error("plugin failure (could not extract wait time)") unless $wait;
			dwait($wait*60);
			$res = $mech->reload();
		} else {
			last;
		}
	}
	
	# Extract the download URL
	$_ = $res->decoded_content."\n";
	my ($url) = m/action=\"([^"]+)\" class=\"captcha\"/;
	return error("plugin error (could not extract download link)") unless $url;
	
	my $download = "$url\" --post-data \"id=".$code."&captcha=1";
	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?easy-share.com");

1;
