#!/usr/bin/env perl
#
# slimrat - OdSibie plugin
#
# Copyright (c) 2009 Yunnan
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
#

package OdSiebie;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Toolbox;
use WWW::Mechanize;

$useragent = "Mozilla/5.0 (Windows; U; Windows NT 6.1; pl; rv:1.9.0.10) Gecko/2009042316 Firefox/3.0.10";
my $mech = WWW::Mechanize->new('agent' => $useragent );

# return - as usual
#   1: ok
#  -1: dead
#   0: don't know

sub check {
	$mech->get(shift);
	return 1  if($mech->content() =~ m/Pobierz plik/);
	# TODO: detect the 302 redirect to the upload form and return -1, otherwise 0
	return -1;
}

sub download {
	my $file = shift;
	$res = $mech->get($file);
	if (!$res->is_success) { print RED "Page #1 error: ".$res->status_line."\n\n"; return 0;}
	else {
	    $_ = $mech->content;
	    $mech->follow_link( text => 'Pobierz plik' );
	    $res = $mech->follow_link( text => 'kliknij tutaj' );
	    if ($res->content_is_html) { print RED &ptime."Error - BURNED HDDs :), too much connections, banned IP, etc.\n\n"; return 0;}
	    $dfilename = $mech->response()->filename;
	    $download = $mech->uri()."\n";
	    return $download."' -O '".$dfilename;
	}
}

Plugin::register(__PACKAGE__,"^[^/]+//(?:www.)?odsiebie.com");

1;

