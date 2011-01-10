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
#    Přemek <premysl.vyhnal at gmail>
#

#
# Configuration
#

# Package name
package HotFile;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;

# Custom packages
use Log;
use Toolbox;
use Configuration;

use ReCaptcha;

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
		
	$self->{CONF}->set_default("username", undef);
	$self->{CONF}->set_default("password", undef);

	if(defined($self->{CONF}->get("username")) and defined($self->{CONF}->get("password"))) {
		Plugin::provide(-1);
	} 


	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success || $self->{PRIMARY}->code == 404);
	dump_add(data => $self->{MECH}->content()) if ($self->{PRIMARY}->is_success);

	return $self;
}

# Plugin name
sub get_name {
	return "HotFile";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m#</strong>\s*(.+?)\s*<span>\|</span>#);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#<span>\|</span> <strong>(.+?)</strong>#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return 1  if (defined $self->{MECH}->form_name("f"));
#	&lang=en
#This file is either removed due to copyright claim or is deleted by the uploader.
	return -1;
}

# Download data
sub get_data_loop  {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;



	#
	# Premium download
	#
	
	if(defined($self->{CONF}->get("username")) and defined($self->{CONF}->get("password"))) {

		$self->{MECH}->submit_form( with_fields => { 
				user => $self->{CONF}->get("username"),
				pass => $self->{CONF}->get("password") });
		dump_add(data => $self->{MECH}->content());
		debug("Using Hotfile Premium account");
		return $self->{MECH}->request(HTTP::Request->new(GET => $self->{URL}, $headers), $data_processor);
	}

	#
	# FREE download
	#

	# Wait timer
	if ((my ($wait1) = $self->{MECH}->content() =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltmr\'\)#)
	    && (my ($wait2) = $self->{MECH}->content() =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltxt\'\)#)) {
		wait(($wait1 + $wait2)/1000);
	}
	
	# Click the button
	if ($self->{MECH}->form_name("f")) {
		$self->{MECH}->submit_form();
		dump_add(data => $self->{MECH}->content());
		return 1;
	}
	
	# reCaptcha
	elsif ($self->{MECH}->content() =~ m#challenge\?k=(.*?)"#) {
		my $recaptcha = ReCaptcha->new($self->{MECH}, $captcha_processor, $1);
		$recaptcha->submit();
		return 1;
	}
	
	# Extract the download URL
	elsif ((my $download) = $self->{MECH}->content() =~ m#href="(.*?)" class="click_download">#) {
		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
	}
	
	return;
}


# Amount of resources
Plugin::provide(1);


# Register the plugin
Plugin::register("^[^/]+//(?:www.)?hotfile.com");

1;

