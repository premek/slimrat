# slimrat - FileHive plugin
#
# Copyright (c) 2008 Přemek Vyhnal
# Copyright (c) 2009 Tim Besard
# Copyright (c) 2009 Mladen Pejaković
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
#    Mladen Pejaković <pejakm-at-gmail-dot-com>
#
# Thanks to:
#    Bartłomiej Palmowski
#

#
# Configuration
#

# Package name
package FileHive;

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
	bless($self);
	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "FileHive";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return "$3\.$4" if ($self->{PRIMARY}->decoded_content =~ m/<(img|embed) src=\"files\/([^<]+)\/([^<]+)\.(jpeg|jpg|png|gif|bmp|tif|tiff|wmv|avi|mpg|mov|asf|swf|JPEG|JPG|PNG|GIF|BMP|TIF|TIFF|WMV|AVI|MPG|MOV|ASF|SWF)\" ><br><br>/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	# only works for images
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<td><b>Size:<\/b><\/td>\s*<td>\s*([^<]+?)\s*<\/td>/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/<font color=red>The uploaded item is not found!<\/font>/);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/Report that this image is illegal or copyrighted/);
	return 0;
}

# Download data
sub get_data_loop  {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;
		
	# Download URL
	if ($self->{MECH}->content() =~ m/<(img|embed) src=\"files\/([^<]+)\/([^<]+)\.(jpeg|jpg|png|gif|bmp|tif|tiff|wmv|avi|mpg|mov|asf|swf|JPEG|JPG|PNG|GIF|BMP|TIF|TIFF|WMV|AVI|MPG|MOV|ASF|SWF)\" ><br><br>/) {
		my $download = "http://www.filehive.com/files/$2/$3.$4";	
		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
	}
	
	return;
}


# Amount of resources
Plugin::provide(-1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?filehive.com");

1;
