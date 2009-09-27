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
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package EasyShare;

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
	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "Easyshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/You are requesting ([^<]+) \(/);
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/You are requesting [^<]+ \(([^)]+)\)/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/msg-err/);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/<title>Download/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	my $captcha_reader = shift;
	
	# Fetch primary page
	$self->reload();

	# Wait timer
	if ($self->{MECH}->content() =~ m/Wait (\d+) seconds/) {
		wait($1);
		$self->reload();
		# Normally the form gets filled in by some Javascript, but upon reload
		# EasyShare detects the user have been waiting and sends the form along.
		# Not ideally, but the only option as we don't support Javascript.
	}
	
	# Get captcha
	if (my $captcha = $self->{MECH}->find_image(url_regex => qr/kaptchacluster/i)) {
		my $captcha_data = $self->{MECH}->get($captcha->url_abs())->content();
		$self->{MECH}->back();
		
		# Process captcha
		my $captcha_code = &$captcha_reader($captcha_data, "jpeg");
		
		# Submit captcha form (TODO: a way to check if the captcha is correct, an is_html on the response?)
		$self->{MECH}->form_with_fields("captcha");
		$self->{MECH}->set_fields("captcha" => $captcha_code);
		my $request = $self->{MECH}->{form}->make_request;
		return $self->{MECH}->request($request, $data_processor);
	}
	
	die("could not match any action");
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?easy-share.com");

1;
