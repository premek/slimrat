# slimrat - FreakShare plugin
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
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#
# Note:
#    FreakShare seems to send an corrupt charset header (prefixing
#    utf8 with a corrupt byte), which creates the need to always
#    use decoded_content with the charset addition. See the
#    WORKAROUND tags, and see if they can be removed later on.
#

#
# Configuration
#

# Package name
package FreakShare;

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
	return "FreakShare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content(charset => "utf8") =~ m/<h1.*?>(.*?) - (.*?)<\/h1>/);	# WORKAROUND
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($2) if ($self->{PRIMARY}->decoded_content(charset => "utf8") =~ m/<h1.*?>(.*?) - (.*?)<\/h1>/);	# WORKAROUND
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return -1 if ($self->{PRIMARY}->decoded_content(charset => "utf8") =~ m/<h1.*?>Error<\/h1>/);	# WORKAROUND
	return 1 if ($self->{PRIMARY}->decoded_content(charset => "utf8") =~ m/value="Free Download"/);	# WORKAROUND
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
	
	# Fetch primary page (FIXME)
	my $res = $self->reload();
	$self->{MECH}->update_html($res->decoded_content(charset => "utf8"));	# WORKAROUND

	# Wait timer
	if ($self->{MECH}->content() =~ m/var time = ([\d\.]+)/ and $1>0) {
		wait($1);
	}
	
	# Navigate to secondary page
	if ($self->{MECH}->content() =~ m/value=\"Free Download\"/ && $self->{MECH}->form_with_fields("section", "did")) {
		my $res = $self->{MECH}->submit_form();
		die("secondary page error, ", $res->status_line) unless ($res->is_success);
		$self->{MECH}->update_html($res->decoded_content(charset => "utf8"));	# WORKAROUND
		dump_add(data => $self->{MECH}->content());
		return 1;
	}
	
	# Click the final Download button
	elsif ($self->{MECH}->content() =~ m/value=\"Download\"/ && $self->{MECH}->form_with_fields("section", "did")) {
		my $request = $self->{MECH}->{form}->make_request;
		$request->header($headers);
		return $self->{MECH}->request($request, $data_processor);
	}
	
	return;
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?freakshare.net");

1;
