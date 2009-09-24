# slimrat - MediaFire plugin
#
# Copyright (c) 2008 Tomasz Gągor
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
#    Tomasz Gągor <timor o2 pl>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package MediaFire;

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
	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "MediaFire";
}

# Filename
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/You requested: ([^(]+) \(/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/You requested: [^(]+ \(([^)]+)\)/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/);
	return -1 if ($self->{MECH}->uri() =~ m/error.php/);
	return 0;
}

# Download data
sub get_data {
	my $self = shift;
	my $data_processor = shift;
	
	# Fetch primary page
	$self->reload();
	
	# Extract secondary page
	$_ = $self->{MECH}->content()."\n";
	my ($qk,$pk,$r) = m/break;}  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/sm;
	
	# Get the secondary page
	my $res = $self->fetch("http://www.mediafire.com/dynamic/download.php?qk=$qk&pk=$pk&r=$r");
	$_ = $res->decoded_content."\n";
	
	# Process the javascript
	if (m/var ([^= ]+)\s*=\s*'([^']*)';/) {
		# Read all variables into hashmap
		my %variables;
		while (s/var ([^= ]+)\s*=\s*'([^']*)';//) {
			$variables{$1} = $2;
		}
		
		# Read and construct the "secret" part of the URL
		my ($url_constr) = m/mL\s*\+'\/'\s*\+(.+)\+\s*'g\/'/;
		$url_constr =~ s/(\w+)\+*/$variables{$1}/g;
		
		# Pass the final download url
		my $download = 'http://' . $variables{"mL"} . '/' . $url_constr . 'g/' . $variables{"mH"} . '/' . $variables{"mY"};
		
		# Download the data
		return $self->{MECH}->request(HTTP::Request->new(GET => $download), $data_processor);
	}
	
	die("could not match any action");
}

# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?mediafire.com");

1;
