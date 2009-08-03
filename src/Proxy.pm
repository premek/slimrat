# slimrat - proxy manager
#
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
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

package Proxy;

# Modules
use Log;
use Configuration;

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("limit_downloads", 5);
$config->set_default("limit_seconds", 0);
$config->set_default("random", 0);

# Browser
my $ua;


#
# Routines
#

# Constructor
sub new {
	my $self;
	my $ua = $_[1];
	
	$self = {
		ua		=>	$ua,
		downloads	=>	0,
		starttime	=>	0,
		uris		=>	[]
	};
	
	bless $self, 'Proxy';
	return $self;

}

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
}

# Advance
sub advance {
	my ($self) = @_;
	
	# Increase counters
	$self->{downloads}++;
	if (!$self->{starttime}) {
		$self->{starttime} = time();
	}	
	
	# Check limits
	my $cycle = 0;
	if ($config->get("limit_downloads")) {
		$cycle = 1 if ($self->{downloads} >= $config->get("limit_downloads"));
	}
	if ($config->get("limit_seconds")) {
		$cycle = 1 if (time() >= $self->{starttime}+$config->get("limit_seconds"));
	}
	
	# Cycle or return
	return $self->cycle() if $cycle;
	return 1;
}

# Cycle
sub cycle {
	my ($self) = @_;
	
	# Read if empty
	if (-f $config->get("list")) {
		error("this stuff ain't working yet, check back later!");
	} elsif ($config->get("list")) {
		error("proxy file nonexistant");
	}
	
	# Reset counters
	$self->{downloads} = 0;
	$self->{starttime} = 0;
	
	# Pick next proxy
	if ($config->get("random")) { # by random
		my $index = rand(scalar(@{$self->{uris}}));
		my $uri = delete($self->{uris}->[$index]);
		unshift(@{$self->{uris}}, $uri);
	} else { # circular
		my $uri = shift(@{$self->{uris}});
		push(@{$self->{uris}}, $uri);
	}
	
	if (scalar(@{$self->{uris}})) {
		$self->{ua}->proxy(["http", "ftp"], "http://blabla:8080");
		return 1;
	} else {
		$self->{ua}->no_proxy();
		return 0;
	}
}

# Return
1;

__END__

=head1 NAME 

Proxy

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 Proxy::new($ua)

Constructs a new proxy handler, with a default configuration and
initially no proxies. Given is an LWP::UserAgent object, on which
the proxy manager shall apply its settings.

=head2 Proxy::configure($config)

Merges the local base config with a set of user-defined configuration
values.

=head2 $proxy->advance()

Check if the current proxy has not yet depleated, and if so call cycle().

=head2 $proxy->cycle()

Cycle to the new proxy. Can be circular, given the configuration.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

