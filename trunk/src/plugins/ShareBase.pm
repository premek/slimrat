# slimrat - ShareBase plugin
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

#
# Configuration
#

# Package name
package ShareBase;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;
use URI::Escape;

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
	return "ShareBase";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<a class="a2"[^>]*>(.*?)<\/a>/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<strong>([\d,BKMG]+)<\/strong>/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if(m/The download doesnt exist/);
	return -1 if(m/Der Download existiert nicht/);
	return -1 if(m/Upload Now !/);
	return 1  if(m/Starting File-Download/);
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
	
	# Click the button to the secondary page

	$self->{MECH}->form_with_fields("free");
	$self->{MECH}->click();
	dump_add(data => $self->{MECH}->content());

	$self->{MECH}->content() =~ m/nCountDown = (\d+?);/;
	wait($1);

	$self->{MECH}->content() =~ m/name="asi" value="([^\"]+)">/s;
	my $req = HTTP::Request->new('POST', $self->{URL}, $headers);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("asi=$1&$1=".uri_escape("Download Now !"));
	return $self->{MECH}->request($req, $data_processor);

	
	 Wait timer
#    elsif( $self->{MECH}->content() =~ m/Du musst noch <strong>([0-9]+)min/ ) {
#        info("reached the download limit for free-users (300 MB)");
#        wait(($1+1)*60);
#        $self->reload();
#        return 1;
#    }

#    return;

}


# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?sharebase.to");

1;
