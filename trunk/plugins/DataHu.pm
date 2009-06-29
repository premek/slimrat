# slimrat - DataHU plugin
#
# Copyright (c) 2009 Gabor Bognar
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
#    Gabor Bognar <wade at wade dot hu>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

# Package name
package DataHu;

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
	my $file = shift;
	$mech->get($file);
	$_ = $mech->content();
	return -1 if(m#error_box#);
	return 1;
}

sub download {
	my $file = shift;
	
	# Get the primary page
	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	while (1) {
		$_ = $res->decoded_content."\n"; 
		
		# Wait timer
		if(m#kell:#) {
			my ($wait) = m#<div id="counter" class="countdown">(\d+)</div>#sm;
			error("plugin error (could not extract wait time)") unless $wait;
			dwait($wait);
			
			$res = $mech->reload();
		} else {
			last;
		}
	}

	# Extract the download URL
	my ($download) = m/class="download_it"><a href="(.*)" onmousedown/sm;
	return error("plugin error (could not extract download link)") unless $download;
	return $download;
}

Plugin::register(__PACKAGE__,"^([^:/]+://)?([^.]+\.)?data.hu");

1;
