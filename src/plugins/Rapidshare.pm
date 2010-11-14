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
use HTTP::Request;

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
	my ($fileid, $filename) = $_[2] =~ m/files\/(.+?)\/(.*)$/;
	$self->{MECH} = $_[3];
	bless($self);
	
	$self->{LOGIN} = 0;
	$self->{PASSWORD} = 0;
	if ($self->{CONF}->defines("username") && $self->{CONF}->defines("password") &&
			($self->{LOGIN} = $self->{CONF}->get("username")) && ($self->{PASSWORD} = $self->{CONF}->get("password"))) {
		Plugin::provide(-1);
	}


	# Reply fields:	
	#	1:File ID
	#	2:Filename
	#	3:Size (in bytes. If size is 0, this file does not exist.)
	#	4:Server ID
	#	5:Status integer, which can have the following numeric values:
	#		0=File not found
	#		1=File OK (Anonymous downloading)
	#		3=Server down
	#		4=File marked as illegal
	#		5=Anonymous file locked, because it has more than 10 downloads already
	#		50+n=File OK (TrafficShare direct download type "n" without any logging.)
	#		100+n=File OK (TrafficShare direct download type "n" with logging. Read our privacy policy to see what is logged.)
	#	6:Short host (Use the short host to get the best download mirror: http://rs$serverid$shorthost.rapidshare.com/files/$fileid/$filename)
	#	7:md5 (See parameter incmd5 in parameter description above.)

	my $checkfiles = $self->api("checkfiles_v1",{
				"files"=>$fileid,
				"filenames"=>$filename
			});
	($self->{FILEID},$self->{FILENAME},$self->{SIZE},$self->{SERVERID},$self->{STATUS},$self->{SHORTHOST},$self->{MD5}) =
		$checkfiles =~ m/^(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),(.+?)$/;

	return $self;
}



# Plugin name
sub get_name {
	return "Rapidshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $self->{FILENAME};
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return $self->{SIZE};
}

# Check if the link is alive
sub check {
	my $self = shift;
	my $s = $self->{STATUS};

	if($s>=100){$s-=100}
	elsif($s>=50){$s-=50}

	return -1 if $s == 0;
	return 1 if $s == 1;
	return 0 if $s == 3; # ?
	return -1 if $s == 4;
	return -1 if $s == 5;

}

# Download data
sub get_data_loop  {
# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;



	# DL:$hostname,$dlauth,$countdown,$md5hex
	$self->api("download_v1", {
			"fileid"=>$self->{FILEID},
			"filename"=>$self->{FILENAME},
			"try"=>1,
			"login"=> $self->{LOGIN},
			"password"=>$self->{PASSWORD}
			});

	if($self->{MECH}->content() =~ /^ERROR: You need to wait (\d+) seconds/){
		wait($1);
		$self->reload();
		return 1;
	}
	
	# Already downloading
	elsif ($self->{MECH}->content() =~ m/ERROR: You need RapidPro to download more files from your IP address/) {
		&$message_processor("already downloading a file");
		wait(2*60);
		$self->reload();
		return 1;
	}
	
	# Slot availability
	elsif ($self->{MECH}->content() =~ m/All free download slots are full/) {
		&$message_processor("All free download slots are full");
		wait(2*60);
		$self->reload();
		return 1;
	}

	# Flooding
	elsif ($self->{MECH}->content() =~ m/Please stop flooding our download servers/) {
		&$message_processor("Rapidshare feels flooded");
		wait(2*60);
		$self->reload();
		return 1;
	}



	# Download limit
	# FIXME is this used?
	elsif ($self->{MECH}->content() =~ m/reached the download limit for free-users/) {
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
	# FIXME is this used?
	elsif ($self->{MECH}->content() =~ m/Currently a lot of users are downloading files\.  Please try again in (\d+) minutes/) {
		my $minutes = $1; 
		&$message_processor("currently a lot of users are downloading files");
		wait($minutes*60);
		$self->reload();
		return 1;
	}

	# Overloaded
	# FIXME is this used?
	elsif ($self->{MECH}->content() =~ m/overloaded/) {
		&$message_processor("RapidShare is overloaded");
		wait(15);
		$self->reload();
		return 1;
	}



	# Another error
	elsif ($self->{MECH}->content() =~ /ERROR: (.*)/){
		die	($1);
	}

	# Download
	elsif ( ($self->{HOSTNAME},$self->{DLAUTH},$self->{COUNTDOWN},$self->{MD5}) =
			$self->{MECH}->content() =~ m/^DL:(.+?),(.+?),(.+?),(.+?)$/) {

		wait($self->{COUNTDOWN});

		my $download = "http://".$self->{HOSTNAME}."/cgi-bin/rsapi.cgi?sub=download_v1".
			"&fileid=".$self->{FILEID}.
			"&filename=".$self->{FILENAME}.
			"&dlauth=".$self->{DLAUTH}.
			"&login=".$self->{LOGIN}.
			"&password=".$self->{PASSWORD};

		return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);

	}

	return;
}



## call RS api subroutine
# http://images.rapidshare.com/apidoc.txt
# param string subroutine
# param hashref parameters
# return server response
sub api{
	my $self = shift;	
	my $sub = shift; # string
	my $params = shift; # hash ref: {"k"=>"v","kk"=>"vv"}

	# I love you, RapidShare!
	my $url = "http://api.rapidshare.com/cgi-bin/rsapi.cgi?sub=$sub";
	while ( my ($key, $value) = each(%{$params}) ) {
		$url.="&$key=".$value;
    }
#	debug($url);
	
	my $resp = $self->{MECH}->get($url);
	die("API call error, ", $resp->status_line) unless ($resp->is_success);

	dump_add(data => $self->{MECH}->content());


	return $self->{MECH}->content();
}





# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?rapidshare.com");

1;
