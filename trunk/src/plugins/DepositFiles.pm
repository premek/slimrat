# slimrat - DepositFiles plugin
#
# Copyright (c) 2008 Přemek Vyhnal
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
#    Přemek Vyhnal <premysl.vyhnal gmail com> 
#    Yunnan <www.yunnan.tk>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#
# Notes:
#    should work with waiting and catches the redownload possibilities without waiting
#

#
# Configuration
#

# Package name
package DepositFiles;

# Extend Plugin
@ISA = qw(Plugin);

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
	$self->{MECH} = $_[3];
	bless($self);
	
	# Fetch the language switch page which gives us a "lang_current=en" cookie
	$self->{MECH}->get('http://depositfiles.com/en/switch_lang.php?lang=en');

	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "DepositFiles";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/File name: <b title="([^<]+)">[^>]*<\/b>/);

}

# Filesize
sub get_filesize {
	my $self = shift;
	
	if ($self->{PRIMARY}->decoded_content =~ m/File size: <b[^>]*>([^<]+)<\/b>/) {
		my $size = $1;
		$size =~ s/\&nbsp;/ /;
		return readable2bytes($size);
	} 
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/does not exist/);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/gateway_result|File Download|will become available/);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/slots for your country are busy/);
	return 0;
}

# Download data
sub get_data_loop {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;
	
	# Download button
	if ($self->{MECH}->form_with_fields("gateway_result")) { # TODO mute "There is no form with the requested fields" error if not found
		$self->{MECH}->submit_form();
		dump_add(data => $self->{MECH}->content());
		return 1;
	} 
	
	# Already downloading
	elsif ($self->{MECH}->content() =~ m/Your IP [0-9.]+ is already downloading/) {
		die("you are already downloading a file from Depositfiles.");
	}
	
	# No free slots
	elsif ($self->{MECH}->content() =~ m/slots for your country are busy/) {
		&$message_processor("All downloading slots for your country are busy");
		wait(30);
		$self->reload();
		return 1;
	}
	
	elsif ($self->{MECH}->content() =~ m/file is not available/s) {
		&$message_processor("File is temporarily not available");
		wait(60);
		$self->reload();
		return 1;
	}
	
	# Wait timer
	elsif ($self->{MECH}->content() =~ m/Please try in\s+(\d+)(?::(\d+))? (min|sec|hour)/s) {
		my ($wait1, $wait2, $time) = ($1, $2, $3);
		if ($time eq "min") {$wait1 *= 60;}
		elsif ($time eq "hour") {$wait1 = 60*($wait1*60 + $wait2);}
		wait($wait1);
		$self->reload();
		return 1;
	}
	
	# Download URL
	elsif ($self->{MECH}->content() =~ m/"repeat"><a href="([^\"]+)">Try downloading this file again/) {
		return $self->{MECH}->request(HTTP::Request->new(GET => $1, $headers), $data_processor);
	}
	
	# Download URL after wait
	elsif ($self->{MECH}->content() =~ m#show_url\((\d+)\)#) {
		wait($1);
		my ($download) = m#<div id="download_url"[^>]>\s*<form action="([^"]+)"#;
		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
	}
	
	return;
}


# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?depositfiles.com");

1;
