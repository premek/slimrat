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

#
# Configuration
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


#
# Routines
#

# Constructor
sub new {
	my $self  = {};
	$self->{URL} = $_[1];
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "Easyshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		if ($res->decoded_content =~ m/You are requesting<strong>([^<]+)<\/strong>/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Filename
sub get_filesize {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		if ($res->decoded_content =~ m/You are requesting<strong>[^<]+<\/strong> \(([^)]+)\)/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		if ($res->decoded_content =~ m/msg-err/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;

	# Get the primary page
	my $res = $self->{MECH}->get($self->{URL});
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
			
			$res = $self->{MECH}->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Download without wait?
		if (m/http:\/\/www.easy-share.com\/c\/(\d+)/) {
			$code = $1;
			$res = $self->{MECH}->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Wait if the site requests to (not yet implemented)
		if(m/some error message/) {
			my ($wait) = m/extract some (\d+) minutes/sm;		
			return error("plugin failure (could not extract wait time)") unless $wait;
			dwait($wait*60);
			$res = $self->{MECH}->reload();
		} else {
			last;
		}
	}
	
	# Extract the download URL
	$_ = $res->decoded_content."\n";
	my ($url) = m/action=\"([^"]+)\" class=\"captcha\"/;
	return error("plugin error (could not extract download link)") unless $url;
	
	# Download the data
	$self->{UA}->request(HTTP::Request->new(POST => $url, [id => $code, captcha => 1]), $data_processor);
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?easy-share.com");

1;
