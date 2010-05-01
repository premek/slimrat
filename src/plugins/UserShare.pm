# slimrat - usershare.net plugin 
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
#    eightmillion <eightmillion-at-gmail-dot-com>
#

#
# Configuration
#

# Package name
package UserShare;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;

# Custom packages
use Log;
use Configuration;
use Toolbox;

# Write nicely
use strict;
use warnings;

sub new {
    my $self  = {};
    $self->{CONF} = $_[1];
    $self->{URL} = $_[2];
    $self->{MECH} = $_[3];
    bless($self);
    
    $self->{PRIMARY} = $self->fetch();
    
    return $self;
}

sub get_name {
    return "UserShare";
}

sub get_filename {
    my $self = shift;

    return $1 if ($self->{PRIMARY}->decoded_content =~ /colspan=2>([^<\r\n]+)/);
}

sub get_filesize {
    my $self = shift;

    return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ /Size:<\/b><\/td><td>([\d\.MbGKB\s]+)(?=\s)/);
}

sub check {
    my $self = shift;
    
    $_ = $self->{PRIMARY}->decoded_content;
    return -1 if(/file is either removed/);
    return 1  if(/download_btn\.jpg/);
    return 0;
}

sub get_data_loop  {
    
    my $self = shift;
    my $data_processor = shift;
    my $captcha_processor = shift;
    my $message_processor = shift;
    my $headers = shift;
    
    $_ = $self->{PRIMARY}->decoded_content();
    die("could not find download link") unless ((my $download) = /<a href="([^"]+)(?="><img src="\/images\/download_btn\.jpg)/);
    dump_add( data => $_ );

    return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
    
}

Plugin::register("^([^:/]+://)?([^.]+\.)?usershare.net");
Plugin::provide(1);


1;
__END__
