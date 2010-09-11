# slimrat - HotFile plugin
#
# Copyright (c) 2010 Přemek
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
#    Premek Vyhnal
#

#
# Configuration
#

# Package name
package Oron;

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

	$self->{MECH}->get('http://oron.com/?op=change_lang&lang=english');

	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success || $self->{PRIMARY}->code == 404);
	dump_add(data => $self->{MECH}->content()) if ($self->{PRIMARY}->is_success);

	return $self;
}

# Plugin name
sub get_name {
	return "Oron";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m#name="fname" value="(.+?)">#);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#</b><br>\s*[^\d]+(\d.*?)<br>#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return 1  if (defined $self->{MECH}->form_with_fields( ("method_free") ));
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

	
	# download link
	if ($self->{MECH}->content() =~ m#<a href="(.*?)" class="atitle">#) {
		return $self->{MECH}->request(HTTP::Request->new(GET => $1, $headers), $data_processor);
	}

	# reCaptcha
	elsif ($self->{MECH}->content() =~ m#challenge\?k=(.*?)"#) {
		# Download captcha
		my $captchascript = $self->{MECH}->get("http://api.recaptcha.net/challenge?k=$1")->decoded_content;
		my ($challenge, $server) = $captchascript =~ m#challenge\s*:\s*'(.*?)'.*server\s*:\s*'(.*?)'#s;
		my $captcha_url = $server . 'image?c=' . $challenge;
		debug("captcha url is ", $captcha_url);
		my $captcha_data = $self->{MECH}->get($captcha_url)->decoded_content;

		my $captcha_value = &$captcha_processor($captcha_data, "jpeg", 1);
		$self->{MECH}->back();
		$self->{MECH}->back();
		
		# Submit captcha form
		$self->{MECH}->submit_form( with_fields => {
				'recaptcha_response_field' => $captcha_value,
				'recaptcha_challenge_field' => $challenge });
		dump_add(data => $self->{MECH}->content());
		return 1;
	}
	
	# Wait timer
	elsif ((my $min, my $sec) = ($self->{MECH}->content() =~ m#wait (?:(\d+) minutes, )?(\d+) seconds#)) {
		$min = 0 unless defined $min;
		wait($min*60 + $sec);
		$self->reload();
		return 1;
	}


	# Click the "free" button
	elsif (defined $self->{MECH}->form_with_fields( "method_free","op" )) {
		$self->{MECH}->click("method_free");
		dump_add(data => $self->{MECH}->content());
		return 1;
	}

	return;
}



# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?oron.com");

1;

