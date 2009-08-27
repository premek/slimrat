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
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package ShareBase;

# Extend Plugin
@ISA = qw(Plugin);

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
	dump_add(data => $self->{MECH}->content());

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

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Download: <\/span><span[^>]*>([^<]+) <\/span>\(/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/Download: <\/span><span[^>]*>[^<]+ <\/span>\(([^)]+)\)<\/td>/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if(m/The download doesnt exist/);
	return -1 if(m/Der Download existiert nicht/);
	return -1 if(m/Upload Now !/);
	return 1  if(m/Download Now !/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Click the button to the secondary page
	$_ = $self->{PRIMARY}->decoded_content;
	my ($asi) = m/name="asi" value="([^\"]+)">/s;	
	my $res = $self->{MECH}->post($self->{URL}, [ 'asi' => $asi , $asi => 'Download Now !' ] );
	return error("plugin failure (page 2 error, ", $res->status_line, ")") unless ($res->is_success);
	dump_add(data => $self->{MECH}->content());
	$_ = $res->content."\n";
	
	# Process the secondary page which leads to the download
	my $counter = 0;
	while (1) {
		my $wait;
		$counter = $counter + 1;
		if( ($wait) = m/Du musst noch <strong>([0-9]+)min/ ) {
		    info("reached the download limit for free-users (300 MB)");
		    wait(($wait+1)*60);
		    $res = $self->{MECH}->reload();
		    dump_add(data => $self->{MECH}->content());
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
	$self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
}


# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?sharebase.to");

1;
