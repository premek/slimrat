# slimrat - NetloadIn plugin
#
# Copyright (c) 2011 Přemek
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
package NetloadIn;

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

	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success || $self->{PRIMARY}->code == 404);
	dump_add(data => $self->{MECH}->content()) if ($self->{PRIMARY}->is_success);

	return $self;
}

# Plugin name
sub get_name {
	return "NetloadIn";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m#dl_first_filename">\s+(.+?)<#s);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#dl_first_filename">\s.+?<span style="color: \#8d8d8d;">, (.+?)</span>#s);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return  1 if ($self->{PRIMARY}->decoded_content =~ m#class="Free_dl"><a href="#);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m#error2\.tpl-->#);
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

		
	# Wait timer
	if ((my $sec) = ($self->{MECH}->content() =~ m#countdown\((\d+),'change\(\)'\)#)) {
		wait($sec/100, 0);
		#$self->reload();
		#return 1;
	}


	# download link
	if ($self->{MECH}->content() =~ m#href="(.+?)"\s*>Click here for the download</a>#) {
		return $self->{MECH}->request(HTTP::Request->new(GET => $1, $headers), $data_processor);
	}

	# captcha
	elsif ($self->{MECH}->content() =~ m#src="(share/includes/captcha\.php\?t=\d+)"#) {
		my $captcha = &$captcha_processor($self->{MECH}->get("http://netload.in/$1")->decoded_content, "png", 0);
		$self->{MECH}->back();
		$self->{MECH}->submit_form( with_fields => { captcha_check => $captcha });
		dump_add(data => $self->{MECH}->content());		
		return 1;
	}


	# Click the "free" button
	elsif ((my $freelink) = $self->{MECH}->content() =~ m#Free_dl"><a href="(.+?)">#) {
		$freelink =~ s/&amp;/&/g;
		my $freelink = "http://netload.in/$freelink&lang=en";
		debug("Going to $freelink");
		$self->{MECH}->get($freelink); # English
		dump_add(data => $self->{MECH}->content());
		return 1;
	}

	return;
}



# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?netload.in");

1;

