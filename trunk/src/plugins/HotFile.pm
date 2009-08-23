# slimrat - HotFile plugin
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
package HotFile;

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
	
	
	$self->{PRIMARY} = $self->{MECH}->get($self->{URL}); # TODO - broken on 404 links
	return error("plugin error (primary page error, ", $self->{PRIMARY}->status_line, ")") unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

	bless($self);
	return $self;
}

# Plugin name
sub get_name {
	return "HotFile";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Downloading <b>(.+?)<\/b>/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/Downloading [^|]*| (.+?)<\/span/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return 1  if(m/Downloading/);
	return -1 unless length; # server returns 0-sized page on dead links
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	my $read_captcha = shift;


	my $download;
	my $watchdog=0;
	my $cont = $self->{PRIMARY}->decoded_content;
	while($watchdog++<3){

		my($wait1, $wait2)=0;
		
		# Extract primary wait timer
		if(($wait1) = $cont =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltmr\'\)#){
			$wait1 /= 1000;
		}

		# Extract secondary wait timer
		if(($wait2) = $cont =~ m#timerend\=d\.getTime\(\)\+(\d+);\s*document\.getElementById\(\'dwltxt\'\)#){
			$wait2 /= 1000;
		}

		# Wait
		wait($wait1 + $wait2);

		# Click the button
		$self->{MECH}->form_name("f") and # free;
		$self->{MECH}->submit_form() and
		dump_add(data => $self->{MECH}->content());	

		# Captcha
		while ($self->{MECH}->content() =~ m#<img src="/(captcha\.php\?id=\d+&hash1=[0-9a-f]+)">#){
			$self->{MECH}->submit_form(with_fields => {"captcha", &$read_captcha("http://hotfile.com/$1")});
			dump_add(data => $self->{MECH}->content());
		}

		# Extract the download URL
		last if ($download = $self->{MECH}->find_link( text => 'Click here to download' ));

		$cont = $self->{MECH}->content();
	}

	return error("plugin error (could not extract download link)") unless $download;
	$download = $download->url();
	
	# Download the data
	$self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?hotfile.com");

1;

