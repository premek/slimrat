# slimrat - FileFactory plugin
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
package FileFactory;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;
use HTML::Entities qw(decode_entities);

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
	return "FileFactory";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<span href="" class="last">(.+)<\/span>/);
	return 0;
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<span>(.*?) file uploaded/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if (m/File Not Found/);
	return 1 if (m/Download Now/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Fetch primary page
	$self->reload();
	
	# Click the "Free Download" button
	if ($self->{MECH}->content() =~ m/\"basicBtn\"/) {
		my $res = $self->{MECH}->follow_link(url_regex => qr/\/dlf\//) || die("could not find primary link");
		die("secondary page error, ", $res->status_line) unless ($res->is_success);
		dump_add(data => $self->{MECH}->content());
	}
	
	# Countdown
	if ($self->{MECH}->content() =~ m/<span id="countdown".+?>(\d+)<\/span>/) {
		wait($1, 0);
	}
	
	# No free slots
	if ($self->{MECH}->content() =~ m/currently no free download slots/) {
		die("no free download slots");
	}
	
	# Download
	if ($self->{MECH}->content() =~ m/\"downloadLink\"/) {
		my $link = $self->{MECH}->find_link(url_regex => qr/\/dl\//) || die("could not find download link");
		return $self->{MECH}->request(HTTP::Request->new(GET => $link->url), $data_processor);
	}
	
	die("could not match any action");
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?filefactory.com");

1;
