# slimrat - Uploading plugin
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

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize 1.52;
use HTTP::Request;

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
	$self->{MECH} = $_[3];	
	bless($self);
	
	# Fetch the language switch page which gives us a "lang=1" cookie (1 => english)
	$self->{MECH}->post('http://uploading.com/general/select_language/', { language => 1});


	$self->{PRIMARY} = $self->fetch();

	return $self;
}

# Plugin name
sub get_name {
	return "Uploading";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m#class="c_1".*^\s+<h2>(.+?)</h2><br/>#sm);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#File size: <b>(.+?)<\/b>#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->code == 404);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m#file is not found#);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m#File download#);
	return 0;
}

# Download data
sub get_data_loop  {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;
	
	# Click the "Download" button
	if ($self->{MECH}->form_id("downloadform")) {
		my $res = $self->{MECH}->submit_form();
		die("page 2 error, ", $res->status_line) unless ($res->is_success);
		dump_add(data => $self->{MECH}->content());
		return 1;
	}
	
	# Daily download limit
	if($self->{MECH}->content() =~ /daily download limit/i) {
		&$message_processor("reached daily download limit, retrying in 3600 seconds");
		wait(3600);
		$self->reload();
		return 1;
	}

	# Wait timer
	if ($self->{MECH}->content() =~ m/setTimeout\('.+', (\d+)\)/) {
	  	wait($1/10);
	}
	
	# Ajax-based download form
	if ($self->{MECH}->content() =~ m/get_link\(\);/) {

		unless ($self->{MECH}->content() =~ m/do_request\('files',\s*'get',\s*{.*?file_id:\s*(\d+),\s*code:\s*"(.*?)",/) {
			die("could not find request download id");
		} 

		my $file_id = $1;
		my $code = $2;

		my $time_id = time()*1000;

		my $req = HTTP::Request->new(POST => "http://uploading.com/files/get/?JsHttpRequest=${time_id}0-xml");
		$req->content_type('application/octet-stream; charset=UTF-8');
		$req->content("file_id=$file_id&code=$code&action=get_link&pass=");
		my $res = $self->{MECH}->request($req);
		die("page 3 error, ", $res->status_line) unless ($res->is_success);

		if ($self->{MECH}->content() =~ m/Please wait/) {
		  wait(60);
		} elsif ($self->{MECH}->content() !~ m/\"answer\".*\"link\".*http/) {
		  return 1;
		}
		
		unless ($self->{MECH}->content() =~ m#(http:\\/\\/[^"]+)#) {
			die("could not find request download url");
	        }
		my $download = $1;
		$download =~ s,\\/,/,g;
		return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
	}

	# Regular download form
        if (my $form = $self->{MECH}->form_name("downloadform")) {
		my $request = $form->make_request;
		$request->header($headers);
		return $self->{MECH}->request($request, $data_processor);
	}

	return;
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?uploading.com");

1;
