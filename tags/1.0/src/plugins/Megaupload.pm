# slimrat - Magaupload plugin
#
# Copyright (c) 2009 Přemek Vyhnal
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
#
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package Megaupload;

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
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "MegaUpload";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Filename:<\/font> <font[^>]*>([^<]+)<\/font/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/File size:<\/font> <font[^>]*>([^<]+)<\/font/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if (m#link you have clicked is not available|This file has expired#);
	return 1 if(m#gencap\.php#);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	my $read_captcha = shift;
	
	# Fetch primary page
	$self->reload();
	
	my ($res, $captcha);
	my $cont = $self->{MECH}->content();
	do {
		# Get captcha
		my ($captcha_url) = $cont =~ m#Enter this.*?src="(http://.*?/gencap.php\?.*?.gif)#ms;
		die("can't get captcha image") unless ($captcha_url);
		
		# Download captcha
		debug("captcha url is ", $captcha_url);
		my $captcha_data = $self->{MECH}->get($captcha_url)->decoded_content;
		$captcha = &$read_captcha($captcha_data, "gif");
		$self->{MECH}->back();

		# Submit captcha form
		$res = $self->{MECH}->submit_form( with_fields => { captcha => $captcha });
		return 0 unless ($res->is_success);
		dump_add(data => $self->{MECH}->content());
		$cont = $self->{MECH}->content();
	} while ($res->decoded_content !~ m#downloadlink#);

	# Wait
	if ($res->decoded_content =~ m#count=(\d+);#) {
		wait($1, 1);
	}

	# Get download url
	if ($res->decoded_content =~ m#downloadlink"><a href="(.*?)"#) {
		my $download = $1;
		return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
	}
	
	die("could not match any action")
}

# Postprocess captcha value
sub ocr_postprocess {
	my ($self, $captcha) = @_;
	$_ = $captcha;
	
	# Whole string replacements
	s/</C/g;
	s/\(/C/g;
	s/\)/D/g;
	s/V1(.+)/D$1/g;
	s/l1/D/g;
	s/\\\.\\/H/g;
	s/N\\/M/g;
	s/V\\/M/g;
	s/VI/M/g;
	s/;\\l\\/M/g;
	s/O/Q/g;
	s/\$/S/g;
	s/'I/T/g;
	s/`\|/T/g;
	s/'\\'/T/g;
	s/7\`/T/g;
	s/'N/TV/g;
	s/\\l/V/g;
	s/\\N/W/g;
	s/ //g;
	
	# First three char replacements
	s/(.{0,2})4/$1A/g;
	
	# Fourth char replacements
	s/L$/1/;
	s/\?$/2/;
	s/A$/4/;
	s/\/$/4/;
	
	return $_;
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//((.*?)\.)?mega(upload|rotic|porn).com/");

1;
