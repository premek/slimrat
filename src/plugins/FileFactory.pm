# slimrat - FileFactory plugin
#
# Copyright (c) 2008-2010 Přemek Vyhnal
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
package FileFactory;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;
use JSON::PP;

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
	return "FileFactory";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<span class="last">(.*?)<\/span>/);
	return 0;
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<span>(.*?) file uploaded/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if (m/File Not Found/);
	return 1 if (m/Download Now/);
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

	dump_add(data => $self->{MECH}->content());

	# No free slots
	if ($self->{MECH}->content() =~ m/currently no free download slots/) {
		&$message_processor("no free download slots");
		wait(60);
		$self->reload();
		return 1;
	}


	if ($self->{MECH}->content() =~ m/<a href="(.+?)" id="downloadLinkTarget"/){
		my $download = $1;
		$self->{MECH}->content() =~ m/<span (?:id|class)="countdown".*?>(\d+)<\/span>/;
		wait($1);
		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
	}




	# reCaptcha
	elsif ($self->{MECH}->content() =~ m#Recaptcha\.create\("(.*?)"#) {
		# Download captcha
		my $captchascript = $self->{MECH}->get("http://api.recaptcha.net/challenge?k=$1")->decoded_content;
		my ($challenge, $server) = $captchascript =~ m#challenge\s*:\s*'(.*?)'.*server\s*:\s*'(.*?)'#s;
		my $captcha_url = $server . 'image?c=' . $challenge;
		debug("captcha url is ", $captcha_url);
		my $captcha_data = $self->{MECH}->get($captcha_url)->decoded_content;

		my $captcha_value = &$captcha_processor($captcha_data, "jpeg", 1);
		$self->{MECH}->back();
		$self->{MECH}->back();
		

		(my $check) = $self->{MECH}->content() =~ m#check:'(.+?)'#;

		$self->{MECH}->post("http://filefactory.com/file/checkCaptcha.php", {
				"recaptcha_challenge_field"=>$challenge,
				"recaptcha_response_field"=>$captcha_value,
				"recaptcha_shortencode_field"=>"undefined",
				"check"=>$check				
				});
		dump_add(data => $self->{MECH}->content());
		my $response = JSON::PP->new->allow_barekey->decode($self->{MECH}->content());
		$self->{MECH}->back();


		return 1 if ($response->{status} eq "fail"); # wrong captcha code


		if ($response->{status} eq "ok"){
			my $download = "http://filefactory.com".$response->{path};
			$self->{MECH}->head($download);
			if($self->{MECH}->is_html()){
				$self->{MECH}->get($download);
				return 1;
			} else {
				return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
			}
		}

	}

	
	
	
	return;
}


# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?filefactory.com");

1;
