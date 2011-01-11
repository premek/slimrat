# slimrat - Share-Rapid.com plugin
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
#

#
# Configuration
#

# Package name
package ShareRapidCom;

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
	
	$self->{CONF}->set_default("username", undef);
	$self->{CONF}->set_default("password", undef);

	$self->{MECH}->add_header( Accept => 'application/xml' );
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "Share-Rapid.com";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m#<title>(.+?) - Share-Rapid</title>#);
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#Velikost:</td>\s*<td class="h"><strong>\s*(.+?)<#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	return -1 if ($self->{PRIMARY}->code == 404);
	return 1 if ($self->{PRIMARY}->decoded_content =~ m#class="souborinfo"#);
	return 0;
}

# Download data
sub get_data_loop {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;

	die("account information not configured") unless (
			defined($self->{CONF}->get("username")) and
			defined($self->{CONF}->get("password")));

	$self->{MECH}->add_header( Accept => undef );
	$self->{MECH}->credentials( $self->{CONF}->get("username"), $self->{CONF}->get("password") );	
	return $self->{MECH}->request(HTTP::Request->new(GET => $self->{URL}, $headers), $data_processor);
}


# Amount of resources
Plugin::provide(3);


# Register the plugin
Plugin::register("^[^/]+//(?:www.)?(share-rapid\\.(com|info|cz|eu|info|net|sk)|((mediatack|rapidspool|e-stahuj|premium-rapidshare|qiuck|rapidshare-premium|share-credit|share-free|srapid)\\.cz)|((strelci|share-ms|)\\.net)|jirkasekyrka\\.com|((kadzet|universal-share)\\.com)|sharerapid\\.(biz|cz|net|org|sk)|stahuj-zdarma\\.eu|share-central\\.cz)");

1;

