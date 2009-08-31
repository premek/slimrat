# slimrat - direct downloading plugin
#
# Copyright (c) 2008 Přemek Vyhnal
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
package Direct;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use LWP::UserAgent;

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
	
	$self->{CONF}->set_default("enabled", 0);
	if ($self->{CONF}->get("enabled")) {
		warning("no appropriate plugin found, using 'Direct' plugin");
	} else {
		die("no appropriate plugin found");
	}

	eval($self->{HEAD} = $self->{MECH}->head($self->{URL}));
	die("URL not usable") if ($!);

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "Direct";
}

# Get filename
sub get_filename {
	my $self = shift;
	
	# Get filename through HTTP request
	my $filename = $self->{HEAD}->filename;
	
	# If unsuccessfull, deduce from URL
	$filename = ((URI->new($self->{URL})->path_segments)[-1]) unless ($filename);
	return $filename;
}

# Filesize
sub get_filesize {
	my $self = shift;
	return $self->{HEAD}->content_length;
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return 1 if ($self->{HEAD}->is_success);
	return -1;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	my $read_captcha = shift;
	my $headers = shift || [];
	
	$self->{MECH}->request(HTTP::Request->new(GET => $self->{URL}, $headers), $data_processor);
}

# Amount of resources
Plugin::provide(-1);

# Return
1;

