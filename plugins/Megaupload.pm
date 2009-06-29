# slimrat - Magaupload plugin
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
package Megaupload;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent'=>$useragent);


#
# Routines
#

# Constructor
sub new {
	return error("plugin not ported yet");
	my $self  = {};
	$self->{URL} = $_[1];
	
	$self->{UA} = LWP::UserAgent->new(agent=>$useragent);
	$self->{MECH} = WWW::Mechanize->new(agent=>$useragent);
	bless($self);
	return $self;
}

# Check if the link is alive
sub check {
	my $res = $mech->get(shift);
	return -1 if ($res->is_success && $res->decoded_content =~ m#link you have clicked is not available#);
	return 1 if($res->decoded_content =~ m#gencap.php#);
	return 0;
}

sub download {
	my $file = shift;
	my $res;

	do {
		$res = $mech->get($file);
		return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);

		$_ = $res->decoded_content;

		#if(my($minutes) = m#Or wait (\d+) minutes!#) { error("Your Free-Traffic is exceeded, wait $minutes minutes."); return 0; }

		# Download & view captcha image
		my ($captchaimg) = m#Enter this.*?src="(http://.*?/gencap.php\?.*?.gif)#ms;
		return error("can't get captcha image") unless ($captchaimg);
		
		system("wget '$captchaimg' -O mu-captcha.tmp");
		# hmm, hm...
		system("asciiview -kbddriver stdin -driver stdout mu-captcha.tmp"); # TODO config
		unlink("mu-captcha.tmp");

		# Ask the user
		print "Captcha? ";
		my $captcha = <>;
		chomp $captcha;

		# submit captcha form
		$res = $mech->submit_form( with_fields => { captcha => $captcha });
		return 0 unless ($res->is_success);
	} while ($res->decoded_content !~ m#downloadlink#);

	# Wait
	my ($wait) = $res->decoded_content =~ m#count=(\d+);#;
	info("Now we can wait for $wait seconds, but we don't have to.");
	#dwait ($wait);

	# Get download url
	my ($download) = $res->decoded_content =~ m#downloadlink"><a href="(.*?)"#;

	return $download;
}

Plugin::register(__PACKAGE__,"^[^/]+//(.*?)\.mega(upload|rotic|porn).com/");

1;
