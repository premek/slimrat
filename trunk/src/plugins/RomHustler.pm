# slimrat - RomHustler plugin
#
# Copyright (c) 2008-2009 Premek Vyhnal
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
#    Premek Vyhnal <premysl.vyhnal gmail com>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#    Kaleb Elwert <vahki.ttc gmail com>
#
# Plugin details:
##   BUILD 1

#
# Configuration
#

# Package name
package RomHustler;

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
	
	if ($_ = $self->{MECH}->find_link(text_regex => qr/Download this rom/i)) {
		$self->{PRIMARY} = $self->{MECH}->get($_);
	}

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "RomHustler";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m{<title>Rom Hustler - Downloading\.\.\.  (.+?)</title>});
}

# Filesize
sub get_filesize {
	return 0
}

# Check if the link is alive
sub check {
	my $self = shift;

	# Check if the download form is present
	return 1 if ($self->{PRIMARY}->decoded_content =~ m#<h2>Downloading\.\.\.</h2>#);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/Error: Unknown game and\/or system/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	my $counter = $self->{CONF}->get("retry_count");
	my $wait;
	while (1) {		
		# TODO: Wait timer
		if ($self->{MECH}->content() =~ m/Download link will appear in (\d+) seconds/i) {
			wait($1);
		}
		
		# Download URL
		if ($self->{MECH}->content() =~ m#var link_enc=new Array\('((.',')*.)'\);#) {
			my $download = $1;
			$download = join("", split("','", $download));
			
			return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
		}
		
		# Retry
		if ($wait) {
			wait($wait);
			$wait = 0;
		} else {
			warning("could not match any action, retrying");
			die("retry attempt limit reached") unless (--$counter);
			wait($self->{CONF}->get("retry_timer"));
		}
		$self->{MECH}->reload();
		die("error reloading page, ", $self->{MECH}->status()) unless ($self->{MECH}->success());
		dump_add(data => $self->{MECH}->content());
	}
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register('^([^:/]+://)?([^.]+\.)?romhustler\.net');

1;
