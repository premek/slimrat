# slimrat - OdSiebie plugin
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
package OdSiebie;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

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
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	
	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "OdSiebie";
}

# Filename
sub get_filename {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		$res = $self->{MECH}->get($self->{URL});
		if ($res->decoded_content =~ m/Pobierasz plik: ([^<]+)<\/div>/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		$res = $self->{MECH}->get($self->{URL});
		if ($res->decoded_content =~ m/<dt>Rozmiar pliku:<\/dt>\s*<dd> ([^<]+)<\/dd>/s) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		dump_add($self->{MECH}->content(), "html");
		#return -1 if  detect the 302 redirect to the upload form 
		return 1  if($self->{MECH}->content() =~ m/Pobierz plik/);
	}
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Primary page
	my $res = $self->{MECH}->get($self->{URL});
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	dump_add($self->{MECH}->content(), "html");
	
	# Click to the secondary page
	$_ = $self->{MECH}->content;
	$self->{MECH}->follow_link( text => 'Pobierz plik' );
	dump_add($self->{MECH}->content(), "html");
	
	# Click the download link and extract it
	$res = $self->{MECH}->follow_link( text => 'kliknij tutaj');
	if ($res->content_is_html) { error("plugin failure (an unspecified error occured)"); return 0;}
	my $dfilename = $self->{MECH}->response()->filename;
	my $download = $self->{MECH}->uri();
	
	# Download the data
	$self->{UA}->request(HTTP::Request->new(GET => $download), $data_processor);
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?odsiebie.com");

1;

