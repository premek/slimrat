# slimrat - ShareBase plugin
#
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
#    Yunnan <www.yunnan.tk>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

# Package name
package ShareBase;

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
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	
	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "ShareBase";
}

# Filename
sub get_filename {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		if ($res->decoded_content =~ m/Download: <\/span><span[^>]*>([^<]+) <\/span>\(/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	my $res = $self->{MECH}->get($self->{URL});
	if ($res->is_success) {
		if ($res->decoded_content =~ m/Download: <\/span><span[^>]*>[^<]+ <\/span>\(([^)]+)\)<\/td>/) {
			return $1;
		} else {
			return 0;
		}
	}
	return 0;
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$self->{MECH}->get($self->{URL});
	return -1 if($self->{MECH}->content() =~ m/The download doesnt exist/);
	return -1 if($self->{MECH}->content() =~ m/Der Download existiert nicht/);
	return -1 if($self->{MECH}->content() =~ m/Upload Now !/);
	return 1  if($self->{MECH}->content() =~ m/Download Now !/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Get the primary page
	my $res = $self->{MECH}->get($self->{URL});
	return error("plugin failure (page 1 error, ", $res->status_line, ")") unless ($res->is_success);
	
	# Click the button
	$_ = $res->content."\n";
	my ($asi) = m/name="asi" value="([^\"]+)">/s;
	
	
	$res = $self->{MECH}->post($self->{URL}, [ 'asi' => $asi , $asi => 'Download Now !' ] );
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	$_ = $res->content."\n";
	
	# Process the secondary page
	my $counter = 0;
	while (1) {
		my $wait;
		$counter = $counter + 1;
		if( ($wait) = m/Du musst noch <strong>([0-9]+)min/ ) {
		    info("reached the download limit for free-users (300 MB)");
		    wait(($wait+1)*60);
		    $res = $self->{MECH}->reload();
		    $_ = $res->content."\n";
		} elsif( $self->{MECH}->uri() =~ $self->{URL} ) {
		    info("something wrong, waiting 60 sec");
		    wait(60);
		} else {
		    last;
		}
		if($counter > 5) {
			error("plugin failure (loop error)"); die();
		}
	}
	
	my $download = $self->{MECH}->uri();
	
	# Download the data
	$self->{UA}->request(HTTP::Request->new(GET => $download), $data_processor);
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?sharebase.to");

1;
