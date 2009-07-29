# slimrat - UploadedTo plugin
#
# Copyright (c) 2009 Přemek Vyhnal
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
#    Přemek Vyhnal
#

#
# Configuration
#

# Package name
package UploadedTo;

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
	$self->{MECH} = $_[3];
	
	
	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	return error("plugin error (primary page error, ", $self->{PRIMARY}->status_line, ")") unless ($self->{PRIMARY}->is_success);
	dump_add($self->{MECH}->content());

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "UploadedTo";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1.$2 if ($self->{PRIMARY}->decoded_content =~ m/Filename: \&nbsp;<\/td><td><b>\s*([^<]+?)\s+<\/b>.*Filetype: \&nbsp;<\/td><td>\s*([^<]*)\s*<\/td>/s);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/Filesize: \&nbsp;<\/td><td>\s*([^<]+?)\s*<\/td>/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->decoded_content =~ m#File doesn't exist#);
	return 1;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;

	$_ = $self->{PRIMARY}->decoded_content."\n";

	# TODO: actually wait here
	if(my($minutes) = m#Or wait (\d+) minutes!#) { error("Your Free-Traffic is exceeded, wait $minutes minutes."); return 0; }

	# Extract url
	my ($download) = m#<form name="download_form" method="post" action="(.+?)">#;
	if (!$download) { error("plugin failure (could not find url)"); return 0; }		
	
	# Download the data
	my $req = HTTP::Request->new(POST => $download);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("download_submit=Free%20Download");
	$self->{MECH}->request($req, $data_processor);
}

Plugin::register(__PACKAGE__,"^[^/]+//(uploaded.to/file|ul.to)/");

1;
