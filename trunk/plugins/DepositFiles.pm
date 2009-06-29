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

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new(agent => $useragent );


#
# Routines
#

# Constructor
sub new {
	return error("plugin not ported yet");
	my $self  = {};
	$self->{URL} = $_[1];
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	bless($self);
	return $self;
}

# Check if the link is alive
sub check {
	my $res = $mech->get(shift);
	if ($res->is_success) {
		if ($res->decoded_content =~ m/does not exist/) {
			return -1;
		} else {
			return 1;
		}
	}
	return 0;
}


sub download {
	my $file = shift;
	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	$_ = $mech->content();
	if (m/slots for your country are busy/) { error("all downloading slots for your country are busy"); return 0;}
	my $re = '<div id="download_url"[^>]>\s*<form action="([^"]+)"';
	
	my $download;
	if(!(($download) = m/$re/)) {
		$mech->form_number(2);
		$mech->submit_form();
		$_ = $mech->content();
		my $wait;
		if (($wait) = m#Please try in\D*(\d+) min#) {
			dwait($wait*60);
			$mech->reload();
			$_ = $mech->content();
		}
		elsif (($wait) = m#Please try in\D*(\d+) sec#) {
			dwait($wait);
			$mech->reload();
			$_ = $mech->content();
		}
		if (m/Try downloading this file again/) {
			($download) = m#<td class="repeat"><a href="([^\"]+)">Try download#;
		} else {
			($wait) = m#show_url\((\d+)\)#;
			dwait($wait);
			($download) = m#$re#;
			return error("plugin error (could not extract download link)") unless $download;
		}
	}
	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?depositfiles.com");

1;
