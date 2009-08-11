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

# Package name
package Proxy;

# Packages
use Class::Struct;

# Custom packages
use Log;
use Configuration;
use Toolbox;

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("limit_downloads", 5);
# TODO $config->set_default("limit_seconds", 0);
# TODO $config->set_default("limit_bytes", 0);
$config->set_default("order", "linear");
$config->set_default("delete", 0);

# Browser
my $ua;

# A proxy item
struct(ProxyData =>	{
		link		=>	'$',
		protocols	=>	'$',
		downloads	=>	'$'
});


#
# Routines
#

# Constructor
sub new {
	my $self;
	my $ua = $_[1];
	
	$self = {
		ua		=>	$ua,
		proxies		=>	[],
		flags		=>	0
	};
	
	bless $self, 'Proxy';
	return $self;

}

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
}

# Initialize proxy handler
sub init($) {
	my ($self) = @_;
	
	# Read proxies
	if ($config->get("list")) {
		return fatal("could not read proxy file") unless (-r $config->get("list"));
		$self->file_read();
	}
	
	$self->set();
}

# Advance
sub advance {
	my ($self, $protocol) = @_;
	
	# Initialize once (TODO: should fit better at configure(), but that's a static method!)
	if (! $self->{flags} & 1) {
		$self->{flags} |= 1;
		$self->init();
	}
	
	# No need to do anything if no proxies available
	return 1 unless (scalar(@{$self->{proxies}}));
	
	# Check limits and cycle if needed
	my $cycle = 0;
	if ($config->get("limit_downloads")) {
		$cycle = 1 if ($self->{proxies}->[0]->downloads() >= $config->get("limit_downloads"));
	}
	#if ($config->get("limit_seconds")) {
	#	$cycle = 1 if (time() > $self->{starttime}+$config->get("limit_seconds"));
	#}
	$self->cycle(1) if $cycle;
	
	# Check for protocol match
	my $limit = scalar(@{$self->{proxies}});
	while (scalar(@{$self->{proxies}}) && indexof($protocol, $self->{proxies}->[0]->protocols()) == -1) {
		$self->cycle(0);
		if (--$limit < 0) {
			return error("could not find proxy matching current protocol '$protocol'");
		}
	}
	
	# Increase counters
	$self->{proxies}->[0]->{downloads}++;
	#$self->{bytes} += $self->{ua}->get_bytes();
	
	# Cycle or return
	return 1;
}

# Cycle
sub cycle {
	my ($self, $limits_reached) = @_;
	debug("cycling!");
	
	# Place current proxy at end
	my $proxy = shift(@{$self->{proxies}});
	if ($limits_reached) {
		$proxy->downloads(0);
		push(@{$self->{proxies}}, $proxy) unless $config->get("delete");
	} else {
		push(@{$self->{proxies}}, $proxy);
	}
	
	# Pick next proxy
	if ($config->get("order") eq "random") {
		my $index = rand(scalar(@{$self->{proxies}}));
		my $uri = delete($self->{proxies}->[$index]);
		$self->{proxies}->[$index] = shift(@{$self->{proxies}}); # because delete() creates an undef spot
		unshift(@{$self->{proxies}}, $uri);
	} elsif ($config->get("order") eq "linear") {
		# Nothing to do, default behaviour is linear
	} else {
		return error("unrecognized proxy order '", $config->get("order"), "'");
	}
	
	$self->set();
}

# Activate a proxy
sub set($) {
	my ($self) = @_;
	
	# Select proxy if available
	if (scalar(@{$self->{proxies}})) {
		my $proxy = $self->{proxies}->[0];
		info("Using proxy '", $proxy->link(), "' for protocols ", join(" and ", @{$proxy->protocols()}));
		$self->{ua}->proxy($proxy->protocols(), $proxy->link());
		return 1;
	} else {
		info("Disabled proxies");
		$self->{ua}->no_proxy();
		return 0;
	}
}

# Read proxy file
sub file_read() {
	my ($self) = @_;
	debug("reading proxy file '", $config->get("list"), "'");

	open(FILE, $config->get("list")) || fatal("could not read proxy file");
	while (<FILE>) {
		# Skip things we don't want
		next if /^#/;		# Skip comments
		next if /^\s*$/;	# Skip blank lines
		
		# Process a valid proxy
		if ($_ =~ m/^\s*(\S+)\t(\S+)\s*/) {
			my $link = $1;
			my $protocols_string = $2;
			my @protocols = [split(/,/, $protocols_string)];
			
			my $proxy = ProxyData->new();
			$proxy->link($link);
			$proxy->protocols(@protocols);
			$proxy->downloads(0);
			
			push(@{$self->{proxies}}, $proxy);
		} else {
			warning("unrecognised line in proxy file: '$_'");
		}
	}
	close(FILE);
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

=head2 $proxy->set()

This configures the UserAgent object to use the current proxy, internally used
after a cycle() or at initialisation.

=head2 $proxy->advance($protocol)

Check if the current proxy has not yet depleted, and if so call cycle(). The current
proxy is also checked to match the given protocol.

=head2 $proxy->cycle($limits_reached)

Cycle to the new proxy. Depending on the specified order in the configuration
object, a new proxy will get selected. When the $limits_reached variable is set,
and the configuration value "delete" indicates that used proxies should get deleted,
the current proxy will get deleted, instead of being pushed at the end of the
proxy queue.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

