# slimrat - Rapidshare plugin
#
# Copyright (c) 2008-2009 Přemek Vyhnal
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
package Rapidshare;

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
	
	$self->{MECH} = WWW::Mechanize->new(agent => $useragent);
	
	$self->{CONF}->set_default("interval", 0);

	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	return error("plugin error (primary page error, ", $self->{PRIMARY}->status_line, ")") unless ($self->{PRIMARY}->is_success);
	dump_add($self->{MECH}->content());

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "Rapidshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+\/([^<]+) </) {
		return $1;
	} else {
		return 0;
	}
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+ <font[^>]*>\| ([^<]+)<\/font/) {
		return readable2bytes($1);
	} else {
		return 0;
	}
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	# Check if the download form is present
	if ($self->{PRIMARY}->decoded_content =~ m/form id="ff" action/) {
		return 1;
	} else {
		return -1;
	}
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Click the "Free" button
	$self->{MECH}->form_number(1);
	my $res = $self->{MECH}->submit_form();
	return error("plugin failure (secondary page error, ", $res->status_line, ")") unless ($res->is_success);
	dump_add($self->{MECH}->content());
	
	# Process the resulting page
	while(1) {
		my $wait;
		$_ = $res->decoded_content."\n"; 

		if(m/reached the download limit for free-users/) {
			($wait) = m/Or try again in about (\d+) minutes/sm;
			info("Reached the download limit for free-users");
			
		} elsif(($wait) = m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
			info("Currently a lot of users are downloading files");
		} elsif(($wait) = m/no available slots for free users\. Unfortunately you will have to wait (\d+) minutes/) {
			info("No available slots for free users");

		} elsif(m/already downloading a file/) {
			info("Already downloading a file");
			$wait = 1;
		} else {
			last;
		}
		
		if ($self->{CONF}->get("interval") && $wait > $self->{CONF}->get("interval")) {
			info("Should wait $wait minutes, interval-check in " . $self->{CONF}->get("interval") . " minutes");
			$wait = $self->{CONF}->get("interval");
		}
		wait($wait*60);
		$res = $self->{MECH}->reload();
		dump_add($self->{MECH}->content());
	}
	
	# Extract the download URL
	my ($download, $wait) = m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm;
	return error("plugin error (could not extract download link)") unless $download;
	wait($wait);

	$self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
}

# Register the plugin
Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?rapidshare.com");

1;
