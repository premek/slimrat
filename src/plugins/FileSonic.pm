# slimrat - FileSonic.com plugin
#
# Copyright (c) 2010 Přemek Vyhnal
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

#
# Configuration
#

# Package name
package FileSonic; # ex- sharingmatrix.com

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
	
	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

	return $self;
}

# Plugin name
sub get_name {
	return "FileSonic";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m#<title>Download (.*?) for free#);
}

# Filesize
sub get_filesize {
	my $self = shift;
	my $size;

	return readable2bytes($size) if (($size) = $self->{PRIMARY}->decoded_content =~ m#<span class="size">(.*?)</span>#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if (m#<input type="hidden" name="linkId" value="" />#); # empty id
	return 1 if(m#<p class="fileInfo filename">#);
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


	if ($self->{MECH}->content() =~ m#<a href="(http://s\d+\.filesonic\.com/download/.+?)">#) {
		return $self->{MECH}->request(HTTP::Request->new(GET => $1, $headers), $data_processor);
	}

	# reCaptcha
	elsif ($self->{MECH}->content() =~ m#Recaptcha\.create\("(.*?)"#) {
		my $recaptcha = ReCaptcha->new($self->{MECH}, $captcha_processor, $1);
		
		# nonstandard submit, not using ReCaptcha->submit()
		$self->{MECH}->add_header( 'X-Requested-With'=>'XMLHttpRequest' );
		$self->{MECH}->post($self->{URL}."?start=1", {
				'recaptcha_response_field' => $recaptcha->get_value(),
				'recaptcha_challenge_field' => $recaptcha->get_challenge()
				});
		$self->{MECH}->add_header( 'X-Requested-With'=>undef );

		dump_add(data => $self->{MECH}->content());
		return 1;
	}
	
	elsif ($self->{MECH}->content() =~ m#countDownDelay = (\d+)#) {
		wait($1);
		my($tm, $tm_hash) = $self->{MECH}->content() =~ m#id='tm'.*?value='(\d+)' />.*id='tm_hash'.*?value='(.+?)'#s;
		$self->{MECH}->post($self->{URL}."?start=1", {
				'tm' => $tm,
				'tm_hash' => $tm_hash});
		dump_add(data => $self->{MECH}->content());
		return 1;
	}

	else {

		$self->{MECH}->add_header( 'X-Requested-With'=>'XMLHttpRequest' );
		$self->{MECH}->post($self->{URL}."?start=1");
		$self->{MECH}->add_header( 'X-Requested-With'=>undef );
		dump_add(data => $self->{MECH}->content());
		return 1;
	}

	return;


}

# Amount of resources
Plugin::provide(-1);

# Register the plugin
Plugin::register("^[^/]+//((.*?)\.)?(filesonic|sharingmatrix).com/");

1;
