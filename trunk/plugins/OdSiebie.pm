# slimrat - OdSiebie plugin
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
package OdSiebie;

# Modules
use Log;
use Toolbox;
use WWW::Mechanize;

# Write nicely
use strict;
use warnings;

my $mech = WWW::Mechanize->new('agent' => $useragent );


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
	$mech->get(shift);
	return 1  if($mech->content() =~ m/Pobierz plik/);
	# TODO: detect the 302 redirect to the upload form and return -1, otherwise 0
	return -1;
}

sub download {
	my $file = shift;
	
	# Get the page
	my $res = $mech->get($file);
	return error("plugin failure (", $res->status_line, ")") unless ($res->is_success);
	
	$_ = $mech->content;
	$mech->follow_link( text => 'Pobierz plik' );
	$res = $mech->follow_link( text => 'kliknij tutaj' );
	if ($res->content_is_html) { error("plugin failure (an unspecified error occured)"); return 0;}
	my $dfilename = $mech->response()->filename;
	
	my $download = $mech->uri()."\n";
	return $download."' -O '".$dfilename;
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?odsiebie.com");

1;

