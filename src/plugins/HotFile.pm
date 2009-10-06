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
#
# Plugin details:
##   BUILD 2
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
	
	
	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success || $self->{PRIMARY}->code == 404);
	dump_add(data => $self->{MECH}->content()) if ($self->{PRIMARY}->is_success);

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "HotFile";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Downloading <b>(.+?)<\/b>/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/Downloading [^|]*| (.+?)<\/span/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1  if ($self->{PRIMARY}->decoded_content =~ m/file is either removed/); # when link is removed by uploader
	return -1 if ($self->{PRIMARY}->code == 404); # when 2nd number in link is wrong
	return -1 unless length $self->{PRIMARY}->decoded_content; # when 1st number in link is wrong
	return 1  if ($self->{PRIMARY}->decoded_content =~ m/Downloading/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	my $read_captcha = shift;
	
	# Fetch primary page
	$self->reload();

	# Wait timer
	if ((my ($wait1) = $self->{MECH}->content() =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltmr\'\)#)
		&& (my ($wait2) = $self->{MECH}->content() =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltxt\'\)#)) {
			wait(($wait1 + $wait2)/1000);
	}
	
	# Click the button
	if ($self->{MECH}->form_name("f")) {
		$self->{MECH}->submit_form();
		dump_add(data => $self->{MECH}->content());
	}
	
	# Captcha
	if ($self->{MECH}->content() =~ m#<img src="/(captcha\.php\?id=\d+&hash1=[0-9a-f]+)">#) {
		# Download captcha
		my $captcha_url = "http://hotfile.com/$1";
		debug("captcha url is ", $captcha_url);
		my $captcha_data = $self->{MECH}->get($captcha_url)->decoded_content;
		my $captcha_value = &$read_captcha($captcha_data, "jpeg");
		$self->{MECH}->back();
		
		# Submit captcha form
		$self->{MECH}->submit_form(with_fields => {"captcha", $captcha_value});
		dump_add(data => $self->{MECH}->content());
	}
	
	# Extract the download URL
	if (my $download = $self->{MECH}->find_link( text => 'Click here to download')) {
		$download = $download->url();
		return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
	}
	
	die("could not match any action");
}

# Preprocess captcha image
sub ocr_preprocess {
	my ($self, $captcha_file) = @_;
	
	# Remove the image background
	system("convert $captcha_file -fuzz 37% -fill black -opaque \"rgb(209,209,209)\" -fuzz 0% -fill white -opaque black -fill black +opaque white $captcha_file"); 
}

# Postprocess captcha value
sub ocr_postprocess {
	my ($self, $captcha_value) = @_;
	$_ = $captcha_value;
	
	# Fix common errors
	s/q/a/;
	s/8/a/;
	s/¤/a/;
	s/°/a/;
	s/.;/a/;
	s/2/e/;
	s/é/e/;
	s/@/e/;
	s/5/e/;
	s/9/e/;
	s/©/e/;
	s/¢/e/;
	s/\&/e/;
	s/;/e/;
	s/€/e/;
	s/Q/g/;
	s/\\/i/;
	s/:/l/;
	s/\|/l/;
	s/0/o/;
	s/$/s/;
	s/\?/t/;
	s/\+/t/;
	s/\'I\‘/t/;
	
	# Clean clutter, remove whitespaces
	s/.//;
	s/-//;
	s/ //;
	
	# Replace uppercase letters with lowercase
	$_ = lc($_);
	
	# TODO: spellcheck
	
	return $_;
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?hotfile.com");

1;

