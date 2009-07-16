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

# Packages
use WWW::Mechanize;

# Custom packages
use Log;
use Toolbox;
use Configuration;

# Write nicely
use strict;
use warnings;


#
# Routines
#

# Constructor
sub new {
	my $self  = {};
	$self->{CONF} = $_[1];
	$self->{URL} = $_[2];
	
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
		if ($res->decoded_content =~ m/You are requesting<strong> ([^<]+)<\/strong>/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Filesize
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
	return error("plugin failure (page 1 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Click the "Free" button
	$self->{MECH}->form_number(1);
	$res = $self->{MECH}->submit_form();
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Process the resulting page
	my $code;
	while (1) {
		my $content = $res->decoded_content."\n";
		
		# Wait timer?
		if ($content =~ m/Seconds to wait: (\d+)/) {
			# Wait
			wait($1);
		}
		
		# Captcha extraction
		if ($content =~ m/\/file_contents\/captcha_button\/(\d+)/) {
			$code = $1;
			print "Got captcha through button: $code\n";
			return error("plugin failure (could not extract captcha code)") unless $code;
			
			$res = $self->{MECH}->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Download without wait?
		if ($content =~ m/http:\/\/www.easy-share.com\/c\/(\d+)/) {
			$code = $1;
			print "Got captcha directly: $code\n";
			$res = $self->{MECH}->get('http://www.easy-share.com/c/' . $code);
			last;
		}
		
		# Wait if the site requests to (not yet implemented)
		if($content =~ m/some error message/) { #TODO: find what EasyShare does upon wait request
			my ($wait) = m/extract some (\d+) minutes/sm;		
			return error("plugin failure (could not extract wait time)") unless $wait;
			wait($wait*60);
			$res = $self->{MECH}->reload();
			next;
		}
		
		# We got a problem here
		return error("plugin failure (page 2 error, could not match any action)");
	}
	
	# Get the third page
	$res = $self->{MECH}->get('http://www.easy-share.com/c/' . $code);
	return error("plugin failure (page 3 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Extract the download URL
	$_ = $res->decoded_content."\n";
	my ($url) = m/action=\"([^"]+)\" class=\"captcha\"/;
	return error("plugin error (could not extract download link)") unless $url;
	
	# Download the data
	my $req = HTTP::Request->new(POST => $url);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("id=$code&captcha=1");
	$self->{UA}->request($req, $data_processor);
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?easy-share.com");

1;
