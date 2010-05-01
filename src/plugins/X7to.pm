# slimrat - x7.to plugin 
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
package X7to;

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

    # Set the language
    $self->fetch("http://x7.to/lang/en");    

    return $self;
}

sub get_name {
    return "x7.to";
}

sub get_filename {
    my $self = shift;

    return $1 if ($self->{PRIMARY}->decoded_content =~ /(?<=content="Download: )([^(]+)(?=\s)/);
}

sub get_filesize {
    my $self = shift;

    return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ /(?<=content="Download: )[^(]+\(([^)]+)/);
}

sub check {
    my $self = shift;
    
    $_ = $self->{PRIMARY}->decoded_content;
    return -1 if(m/You will be redirected to our/);
    return 1  if(m/Download/);
    return 0;
}

sub get_data_loop  {
    
    my $self = shift;
    my $data_processor = shift;
    my $captcha_processor = shift;
    my $message_processor = shift;
    my $headers = shift;
    
    $_ = $self->{PRIMARY}->decoded_content();

    # Extract secondary page
    die("could not find file id") unless ((my $ref_file) = /(?<=ref_file=)([^&]+)/);
    dump_add(data => $_);

    # Via http://x7.to/js/download.js
    my $res = $self->{MECH}->get("http://x7.to/james/ticket/dl/".$ref_file);
    die("secondary page error, ", $res->status_line) unless ($res->is_success);
    dump_add(data => $res->content());
    $_ = $res->content();
    
    if (/err:['"]([^'"]+)['"]/){
        if ($1 =~ /limit-dl/){
            &$message_processor("Download limit reached");
        }elsif (/limit-parallel/){
            &$message_processor("You are already downloading a file");
        }else{
            &$message_processor("Unknown error: ".$1);
        }
        wait(300);
        $self->reload();
        return 1;
    }

    if (/type:['"]download['"]/){
        (my $download) = /url:'([^']+)/;
        if (/wait:(\d+)/){
            wait($1);
        }
        return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
    }else{
        die("Unknown error");
        dump_add(data => $res->content());
    }
    
}


Plugin::register("^([^:/]+://)?([^.]+\.)?x7.to");
Plugin::provide(1);


1;
__END__
