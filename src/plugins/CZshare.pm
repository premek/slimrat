# slimrat - CZshare plugin
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
package CZshare;

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

use utf8; # FIXME: hm?

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

	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "CZshare";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m#<span class="text-darkred"><strong>(.+?)</strong></span>#);
}

# Filesize
sub get_filesize {
	my $self = shift;
	
	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#Velikost:</td>\s*<td class="text-left">(.+?)</td>#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	return 1 if ($self->{PRIMARY}->decoded_content =~ m#<span class="nadpis">Download</span>|vyčerpána maximální kapacita FREE downloadů#);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/error/i);
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

	#
	# "PROFI" download
	#
	
	if(defined($self->{CONF}->get("username")) and defined($self->{CONF}->get("password"))) {
		# Download URL
		if ((my ($id) = $self->{MECH}->content() =~ m#<input type="hidden" name="id" value="(.+?)" />#)
			&& (my ($file) = $self->{MECH}->content() =~ m#<input type="hidden" name="file" value="(.+?)" />#)) {
					
			# hm, why Im not able to do this with Mechanize?
			my $res = $self->{MECH}->post("http://czshare.com/prihlasit.php", {
				prihlasit=>1,
				jmeno=>$self->{CONF}->get("username"),
				heslo=>$self->{CONF}->get("password"),
				id=>$id,
				file=>$file,
			});
			die("secondary page error (" . $res->status_line() . ")") unless ($res->is_success);
			dump_add(data => $self->{MECH}->content());
	
			if ($self->{MECH}->content() =~ m#http://.+?/$id/.+?/.+?/# ) {
				return $self->{MECH}->request(HTTP::Request->new(GET => $&, $headers), $data_processor);
			}
		}
	}


	#
	# FREE download
	#
	
	else { 
		# Slot availability
		if ($self->{MECH}->content() =~ m#vyčerpána maximální kapacita FREE downloadů#) {
			&$message_processor("no free slots available");
			wait(60);
			$self->reload();
			return 1;
		}
		
		# Free form
		if ($self->{MECH}->form_with_fields("id","file","ticket")) {
			# Click form
			$self->{MECH}->submit_form();
			dump_add(data => $self->{MECH}->content());
			
			# Solve captcha
			my $captcha;
			do {
				my $cont = $self->{MECH}->content();
				
				# Get captcha
				my ($captcha_url) = $cont =~ m#<img src="(captcha\.php\?ticket=.+?)" />#ms;
				die("can't get captcha image") unless ($captcha_url);
	
				# Download captcha
				my $captcha_data = $self->{MECH}->get($captcha_url)->content();
				$captcha = &$captcha_processor($captcha_data, "png");
				$self->{MECH}->back();
	
				# Submit captcha form
				my $res = $self->{MECH}->submit_form( with_fields => { captchastring => $captcha });
				return 0 unless ($res->is_success);
				dump_add(data => $self->{MECH}->content());
				$self->{MECH}->back() if($self->{MECH}->content() =~ /Error 12/);
			} while ($captcha && $self->{MECH}->content() !~ m#pre_download_form#);
	
			# Generate request
			my($action, $id, $ticket) = $self->{MECH}->content() =~ m#<form name="pre_download_form" action="(.+?)".+name="id" value="(\d+)".+name="ticket" value="(.+?)"#s;# <input type="submit" name="submit_btn" DISABLED value="stahnout " /> 
				my $req = HTTP::Request->new(POST => $action, $headers);
			$req->content_type('application/x-www-form-urlencoded');
			$req->content("id=$id&ticket=$ticket");		
			return $self->{MECH}->request($req, $data_processor);
		}
	}
		
	return;
}



# Preprocess captcha image
sub ocr_preprocess {
	my ($self, $captcha_file) = @_;
	
	# Remove the image background
	system("convert $captcha_file -fuzz 40% -fill white -opaque \"rgb(255,100,22)\" -resize 200%x100%  -colorspace Gray -threshold 5% $captcha_file"); 
}

# Postprocess captcha value
sub ocr_postprocess {
	my ($self, $captcha_value) = @_;
	$_ = $captcha_value;

	
	# Fix common errors

	s/B/8/g;
	s/D/0/g;
	s/E/6/g;
	#s/¤/4/g; # FIXME
	s/il/4/g	if(length > 6);
	s/fl/4/g	if(length > 6);
	s/f1/4/g	if(length > 6);
	s/I1/b/g	if(length > 6); # or h?
	s/\)\(/8/g;
	s/\|1/p/g;
	s/\[:/c/g	if(length > 6);
	s/[Il]{2}/0/g	if(length > 6);
	s/I\]/0/g	if(length > 6);
	s/K</k/g	if(length > 6);
	s/li/6/g	if(length > 6);

	# some more to check
	#]| p
	#|] p
	#| l
	#1: c
	#i1 4
	#Q 4
	#ii 3

	#a e
	#u o
	#n p
	#h b
		
		
	# Replace uppercase letters with lowercase
	$_ = lc($_);

	return $_;
}


# Amount of resources
Plugin::provide(-1);

# Register the plugin
Plugin::register("^([^:/]+://)?([^.]+\.)?czshare.com/");

1;
