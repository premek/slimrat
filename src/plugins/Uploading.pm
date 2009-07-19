# slimrat - Rapidshare plugin
#
# Copyright (c) 2008-2009 Přemek Vyhnal
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

#
# Configuration
#

# Package name
package Uploading;

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
	return "Uploading";
}

# Filename
sub get_filename {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		dump_add($self->{MECH}->content(), "html");
		if ($res->decoded_content =~ m/<h3>Download file\s*<\/h3>\s*<b>([^<]+)<\/b>/) {
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
		dump_add($self->{MECH}->content(), "html");
		if ($res->decoded_content =~ m/File size: ([^<]+)<br/) {
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
	
	# Download the page
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		# Check if the download button is present
		dump_add($self->{MECH}->content(), "html");
		if ($res->decoded_content =~ m/class="downloadbutton"/) {
			return 1;
		} else {
			return -1;
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
	dump_add($self->{MECH}->content(), "html");
	
	# Click the "Download" button
	$self->{MECH}->form_id("downloadform");
	$res = $self->{MECH}->submit_form();
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	dump_add($self->{MECH}->content(), "html");
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n";
		
		if (m/setTimeout\('countdown2\(\)',(\d+)\)/) {
			wait($1/10);
			last;
		}
		else {
			return error("plugin error(could not find match)");
		}
		$res = $self->{MECH}->reload();
		dump_add($self->{MECH}->content(), "html");
	}
	
	# Click the "Free Download" button
	my $form = $self->{MECH}->form_name("downloadform");
	my $request = $form->make_request;
	$self->{MECH}->request($request, $data_processor);
}

# Register the plugin
Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?uploading.com");

1;
