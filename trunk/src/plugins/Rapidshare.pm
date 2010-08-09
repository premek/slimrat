# slimrat - Rapidshare plugin
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

#
# Configuration
#

# Package name
package Rapidshare;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize 1.52;
use HTTP::Request;
#use Crypt::SSLeay;

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
	
	$self->{CONF}->set_default("interval", 0);
	
	# MOVE
	if ($self->{CONF}->defines("username") && $self->{CONF}->get("password") &&
			(my $username = $self->{CONF}->get("username")) && (my $password = $self->{CONF}->get("password"))) {
		Plugin::provide(-1);
	}
	use HTTP::Cookies;
	$self->{MECH}->cookie_jar(HTTP::Cookies->new);  
	
	# Workaround to fix Rapidshare's empty content-type, which makes forms() fail
	# Follow: http://code.google.com/p/www-mechanize/issues/detail?id=124
	my $req = new HTTP::Request("GET", $self->{URL});
	$self->{PRIMARY} = $self->{MECH}->request($req);
	$self->{PRIMARY}->content_type('text/html');
	$self->{MECH}->_update_page($req, $self->{PRIMARY});
	
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

	return $self;
}

# Plugin name
sub get_name {
	return "Rapidshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+\/([^<]+) </);
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<p class="downloadlink">http:\/\/[^<]+ <font[^>]*>\| ([^<]+)<\/font/);
}

# Check if the link is alive
sub check {
	my $self = shift;

	return 1 if ($self->{PRIMARY}->decoded_content =~ m/form id="ff" action/);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/<h1>Error<\/h1>/i);
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
	
	
	#
	# Premium download
	#
	
	if ($self->{CONF}->defines("username") && $self->{CONF}->get("password") &&
			(my $username = $self->{CONF}->get("username")) && (my $password = $self->{CONF}->get("password"))) {
	    # Click the "Premium" button
	    $self->{MECH}->form_number(1);
	    $self->{MECH}->submit();
	    # Enter username and password
	    $self->{MECH}->form_with_fields("accountid");
	    $self->{MECH}->field("accountid",$username);
	    $self->{MECH}->field("password",$password);
	    $self->{MECH}->submit();
	    if($self->{MECH}->form_with_fields("dl.start")){
		# Click download button
		my $request = $self->{MECH}->form_with_fields("dl.start")->click();
		return $self->{MECH}->request($request, $data_processor);
	    } else{
		die "Login failed";
	    }
	}
	
	
	#
	# Free download
	#
	
	else {	
		# Click the "Free" button
		if ($self->{MECH}->form_id("ff")) {
			my $res = $self->{MECH}->submit_form();
			die("secondary page error, ", $res->status_line) unless ($res->is_success);
			dump_add(data => $self->{MECH}->content());
			return 1;
		}
		
		# Download limit
		if ($self->{MECH}->content() =~ m/reached the download limit for free-users/) {
			&$message_processor("reached the download limit for free-users");
			if ($self->{MECH}->content() =~ m/Or try again in about (\d+) minutes/sm) {
				wait($1*60);			
			} else {
				&$message_processor("could not extract wait timer");
				wait(60);
			}
			$self->reload();
			return 1;
		}
		
		# Free user limit
		elsif ($self->{MECH}->content() =~ m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes or become/) {
			my $minutes = $1; 
			&$message_processor("currently a lot of users are downloading files");
			wait($minutes*60);
			$self->reload();
			return 1;
		}
		
		# Overloaded
		elsif ($self->{MECH}->content() =~ m/overloaded/) {
			&$message_processor("RapidShare is overloaded");
			wait(5);
			$self->reload();
			return 1;
		}

		# Slot availability
		elsif ($self->{MECH}->content() =~ m/no more download slots available for free users right now/) {
			&$message_processor("no available slots for free users");
			wait(5*60);
			$self->reload();
			return 1;
		}
		
		# Already downloading
		elsif ($self->{MECH}->content() =~ m/already downloading a file/) {
			die("already downloading a file");
		}
		
		# Download
		elsif ($self->{MECH}->content() =~ m/form name="dlf" action="([^"]+)".*var c=(\d+);/sm) {
			my ($download, $wait) = ($1, $2);
			wait($wait);
			return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
		}
	}
	
	return;
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?rapidshare.com");

1;
