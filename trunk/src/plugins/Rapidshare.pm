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
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package Rapidshare;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize 1.52;
use HTTP::Request;

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
	$self->{CONF}->set_default("interval", 0);
	
	# Workaround to fix Rapidshare's empty content-type, which makes forms() fail
	# Follow: http://code.google.com/p/www-mechanize/issues/detail?id=124
	my $req = new HTTP::Request("GET", $self->{URL});
	$self->{PRIMARY} = $self->{MECH}->request($req);
	$self->{PRIMARY}->content_type('text/html');
	$self->{MECH}->_update_page($req, $self->{PRIMARY});
	
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

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
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+\/([^<]+) </);
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+ <font[^>]*>\| ([^<]+)<\/font/);
}

# Check if the link is alive
sub check {
	my $self = shift;

	return 1 if ($self->{PRIMARY}->decoded_content =~ m/form id="ff" action/);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/<h1>Error<\/h1>/i);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Fetch primary page
	$self->reload();
	
	# Click the "Free" button
	$self->{MECH}->form_id("ff");
	my $res = $self->{MECH}->submit_form();
	die("secondary page error, ", $res->status_line) unless ($res->is_success);
	dump_add(data => $self->{MECH}->content());
	
	# Download limit
	if ($self->{MECH}->content() =~ m/reached the download limit for free-users/) {
		warning("reached the download limit for free-users");
		if ($self->{MECH}->content() =~ m/Or try again in about (\d+) minutes/sm) {
			wait($1*60);			
		} else {
			die("could not extract wait timer");
		}
		$self->reload();
	}
	
	# Free user limit
	if ($self->{MECH}->content() =~ m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
		my $minutes = $1; 
		warning("currently a lot of users are downloading files");
		wait($minutes*60);
		$self->reload();
	}
	
	# Slot availability
	if ($self->{MECH}->content() =~ m/no available slots for free users\. Unfortunately you will have to wait (\d+) minutes/) {
		my $minutes = $1;
		warning("no available slots for free users");
		wait($minutes*60);
		$self->reload();
	}
	
	# Already downloading
	if ($self->{MECH}->content() =~ m/already downloading a file/) {
		die("already downloading a file");
	}
	
	# Download
	if ($self->{MECH}->content() =~ m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm) {
		my ($download, $wait) = ($1, $2);
		wait($wait);
		return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
	}
	
	die("could not match any action");
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?rapidshare.com");

1;
