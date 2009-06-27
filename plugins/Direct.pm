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

#
# Configuration
#

# Package name
package Direct;

# Modules
use Toolbox;
use Log;
use LWP::UserAgent;

# Write nicely
use strict;
use warnings;


#
# Routines
#

# Constructor
sub new {
	my $self  = {};
	$self->{URL} = $_[1];
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
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
	my $filename = ($self->{UA}->head($self->{URL})->filename);
	
	# If unsuccessfull, deduce from URL
	unless ($filename) {
		if ($self->{URL} =~ m/http.+\/([^\/]+)$/)
		{
			$filename = $1;
		}
		else
		{
			error("could not deduce filename");
		}
	}
	return $filename;
}

# Download data
sub get_data {
	my $self = shift;
	
	warning("no plugin for this site, downloading using 'Direct' plugin");
	
	my $data_processor = shift;
	$self->{UA}->request(HTTP::Request->new(GET => $self->{URL}), $data_processor);
}

# Check if link is alive
#   1: ok
#  -1: dead
#   0: don't know
sub check {
	my $self = shift;
	
	return 1 if ($self->{UA}->head($self->{URL})->is_success);
	return -1;
}

1;

