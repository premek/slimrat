# slimrat - DepositFiles plugin
#
# Copyright (c) 2008 Přemek Vyhnal
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
#    Přemek Vyhnal <premysl.vyhnal gmail com> 
#    Yunnan <www.yunnan.tk>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#
# Notes:
#    should work with waiting and catches the redownload possibilities without waiting
#

#
# Configuration
#

# Package name
package DepositFiles;

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
	
	# Force use of English language
	if ($self->{URL} =~ m/(^.+depositfiles\.com\/)(files\/.+$)/) {
		$self->{URL} = $1 . 'en/' . $2;
		debug("english language tag added, URL is now ", $self->{URL});
	} elsif ($self->{URL} =~ m/(^.+depositfiles\.com\/)(\w\w\/)(files\/.+$)/) {
		$self->{URL} = $1 . 'en/' . $3;
		debug("existing language tag ('$3') replaced by english one, URL is now ", $self->{URL});
	}
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	
	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "DepositFiles";
}

# Filename
sub get_filename {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		dump_add($self->{MECH}->content(), $self->{URL});
		if ($res->decoded_content =~ m/File name: <b[^>]*>([^<]+)<\/b>/) {
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
		dump_add($self->{MECH}->content());
		if ($res->decoded_content =~ m/File size: <b[^>]*>([^<]+)<\/b>/) {
			my $size = $1;
			$size =~ s/\&nbsp;/ /;
			return $size;
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
		dump_add($self->{MECH}->content());
		if ($res->decoded_content =~ m/does not exist/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	dump_add($self->{MECH}->content());
	
	$_ = $self->{MECH}->content();
	if (m/slots for your country are busy/) { error("all downloading slots for your country are busy"); return 0;}
	my $re = '<div id="download_url"[^>]>\s*<form action="([^"]+)"';
	
	my $download;
	if(!(($download) = m/$re/)) {
		$self->{MECH}->form_number(2);
		$self->{MECH}->submit_form();
		$_ = $self->{MECH}->content();
		dump_add($self->{MECH}->content());
		
		my $wait;
		if (($wait) = m#Please try in\D*(\d+) min#) {
			wait($wait*60);
			$self->{MECH}->reload();
			$_ = $self->{MECH}->content();
			dump_add($self->{MECH}->content());
		}
		elsif (($wait) = m#Please try in\D*(\d+) sec#) {
			wait($wait);
			$self->{MECH}->reload();
			$_ = $self->{MECH}->content();
			dump_add($self->{MECH}->content());
		}
		if (m/Try downloading this file again/) {
			($download) = m#<td class="repeat"><a href="([^\"]+)">Try download#;
		} else {
			($wait) = m#show_url\((\d+)\)#;
			wait($wait);
			($download) = m#$re#;
			return error("plugin error (could not extract download link)") unless $download;
		}
	}
	
	# Download the data
	$self->{UA}->request(HTTP::Request->new(GET => $download), $data_processor);
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?depositfiles.com");

1;
