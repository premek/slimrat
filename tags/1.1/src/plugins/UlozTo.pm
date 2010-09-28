# slimrat - Uloz.to plugin
#
# Copyright (c) 2010 Přemek Vyhnal
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
package UlozTo;

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
	
	$self->{PRIMARY} = $self->{MECH}->get($self->{URL});
	die("primary page error, ", $self->{PRIMARY}->status_line) unless ($self->{PRIMARY}->is_success);
	dump_add(data => $self->{MECH}->content());

	return $self;
}

# Plugin name
sub get_name {
	return "UlozTo";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m#<b>(.*?)</b></h3>#);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m#<b>(.*?)</b> <br />#);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if (m#error404#);
	return 1 if(m#<img id="captcha"#);
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

	if (my $form = $self->{MECH}->form_name("dwn")) {
		if($self->{MECH}->content() !~ m#src="http://img\.uloz\.to/captcha/(\d+)\.png"#){
			die "cannot find captcha";
		}

		my $captcha_num = $1;
		my $captcha = &$captcha_processor($self->{MECH}->get("http://img.uloz.to/captcha/$captcha_num.png")->decoded_content, "png",1);

		$self->{MECH}->back();

		$self->{MECH}->form_with_fields("captcha_user");
		$self->{MECH}->set_fields("captcha_user" => $captcha);
		my $request = $self->{MECH}->{form}->make_request;
		$request->header($headers);
                
                my $resp = $self->{MECH}->request($request, $data_processor);
	        debug( $resp->as_string);
                
                #when we get HTML page, then something is wrong ... 
                if ($resp->header('content_type') eq 'text/html'){
                    $self->reload();                                                                                                                                                                                 
                    return 1;   
                }
		return $self->{MECH}->request($request, $data_processor);
	}
		
	return;
}

sub ocr_postprocess {
	my ($self, $captcha) = @_;
	$_ = $captcha;
	return if $captcha !~ /^\w{4}$/;
        return $_;
}



# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//((.*?)\.)?(uloz.to|ulozto.sk|ulozto.net|vipfile.pl)/");

1;
