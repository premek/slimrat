# slimrat - StorageTo plugin
#
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
#    Tim Besard <premysl.vyhnal gmail com>
#

#
# Configuration
#

# Package name
package StorageTo;

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

# Constants
my $wait_max_sec = 637;


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
	
	$self->{URL_AUX} = $self->{URL};
	$self->{URL_AUX} =~ s/\/get\//\/getlink\//; 
	
	$self->{AUX} = $self->{MECH}->get($self-> {URL_AUX});
	die("primary page error, ", $self->{AUX}->status_line) unless ($self->{AUX}->is_success);
	dump_add(data => $self->{MECH}->content());

	return $self;
}

# Plugin name
sub get_name {
	return "Storage.To";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Downloading:<\/span> (.*?) <span/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<span class="light">\((.*?)\)<\/span>/);
}

# Check if the link is alive
sub check {
	my $self = shift;

	# Construct hashmap
	my $jsHashMap  = getHashMap($self->{AUX}->decoded_content);

	# Check the state of the link                 
	if ($jsHashMap->{state} eq "ok" || $jsHashMap->{state} eq "wait") {
		return 1;                                                  
	} elsif ($jsHashMap->{state} eq "failed"){
		return -1;
	} else {
		return 0;
	}
}

# Download data
sub get_data_loop  {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;
	
	# Fetch primary page
	$self->{MECH}->get($self->{URL_AUX});
	
	# Construct hashmap
	my $jsHashMap  = getHashMap($self->{MECH}->content());
	
	# Wait timer
	if (defined(my $wait = $jsHashMap->{countdown})) {
		if ($wait > $wait_max_sec) {
			wait($wait-$wait_max_sec, 0);
			$wait -= $wait_max_sec
		}
		wait($wait, 0);
		
		# Check link state
		if ($jsHashMap->{state} eq "wait") {
			$self->load($self-> {URL_AUX});
			$jsHashMap  = getHashMap($self->{MECH}->content());
		} elsif ($jsHashMap->{state} ne "ok") {
			die("wrong link state");
		}
	}
	
	# Get download URL
	if ($jsHashMap->{state} eq "ok") {
		my $download = $jsHashMap->{link};
		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
	}
	
	return;
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
Plugin::register("^[^/]+//(?:www\.)?storage\.to");


#
# Auxiliary
#

# Get hashmap from JSON data provided by Storage.To
sub getHashMap {
        my $jsonSource = shift;
        
        # Strip JS construct
        $jsonSource =~ s/^new Object\((.*)\)$/$1/;
        
        # Get the hashmap
        my $jsonObject = new JSON::PP;
        return $jsonObject->allow_singlequote->decode($jsonSource);
}


1;
