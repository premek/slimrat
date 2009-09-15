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
use threads;
use threads::shared;

# Custom packages
use Log;
use Configuration;
use Toolbox;
use Semaphore;

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

# Shared data
my @proxies:shared; my $s_proxies:shared = new Semaphore;


#
# Static functionality
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	
	$config->path_abs("list");
	
	file_read();
}

# Read proxy file
sub file_read() {
	return 0 unless ($config->contains("file") && -r $config->get("file"));
	debug("reading proxy file '", $config->get("list"), "'");

	open(FILE, $config->get("list")) || fatal("could not read proxy file");
	while (<FILE>) {
		# Skip things we don't want
		next if /^#/;		# Skip comments
		next if /^\s*$/;	# Skip blank lines
		
		# Process a valid proxy
		if ($_ =~ m/^\s*(\S+)\t*(\S*)\s*/) {
			my $link = $1;			
			my $protocols_string = $2 || "http";
			if ($link !~ m/^\S+:\/\//) {
				$link = 'http://' . $link;
			}
			my @protocols = split(/,/, $protocols_string);
			
			# Create shared hash for proxy data
			my $proxy;
			share($proxy);
			$proxy = &share({});
			
			# Save data
			$proxy->{link} = $link;
			share($proxy->{protocols});
			$proxy->{protocols} = &share([]);
			push(@{$proxy->{protocols}}, $_) foreach (@protocols);
			$proxy->{downloads} = 0;
			
			$s_proxies->down();
			push(@proxies, $proxy);
			$s_proxies->up();
		} else {
			warning("unrecognised line in proxy file: '$_'");
		}
	}
	close(FILE);
}

# Quit the package
sub quit {

}


#
# Object-oriented functionality
#

# Constructor
sub new {
	# Configure object
	my $self;
	my $ua = $_[1];	
	$self = {
		ua		=>	$ua,
		proxy	=>	undef
	};	
	bless $self, 'Proxy';
	
	return $self;
}

# Destructor
sub DESTROY {
	my ($self) = @_;
	return unless $self->{proxy};
	
	# Preserve current proxy
	$s_proxies->down();
	push(@proxies, $self->{proxy});
	$s_proxies->up();
	
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

# Advance
sub advance {
	my ($self, $link) = @_;
	
	# No need to do anything if no proxies available
	return 1 unless (scalar(@proxies));
	$s_proxies->down();
	
	# Check limits and cycle if needed
	if (defined($self->{proxy})) {
		my $cycle = 0;
		if ($config->get("limit_downloads")) {
			$cycle = 1 if ($self->{proxy}->{downloads} >= $config->get("limit_downloads"));
		}
		#if ($config->get("limit_seconds")) {
		#	$cycle = 1 if (time() > $self->{starttime}+$config->get("limit_seconds"));
		#}
		$self->cycle(1) if $cycle;
	} else {
		# Pick an initial proxy if we haven't got one yet
		$self->cycle(0);
	}
	$s_proxies->up();
	
	# Check for protocol match
	if ($link =~ /^(.+):\/\//) {
		my $protocol = $1;
		$s_proxies->down();
		my $limit = scalar(@proxies);
		while (scalar(@proxies) && indexof($protocol, $self->{proxy}->{protocols}) == -1) {
			$self->cycle(0);
			if (--$limit < 0) {
				$s_proxies->up();
				return error("could not find proxy matching current protocol '$protocol'");
			}
		}
		$s_proxies->up();
	} else {
		warning("could not deduce protocol, proxies might not work correctly");
	}
	
	# Increase counters
	$self->{proxy}->{downloads}++;
	#$self->{bytes} += $self->{ua}->get_bytes();
	
	# Return
	return 1;
}

# Cycle
sub cycle {
	my ($self, $limits_reached) = @_;
	
	# Place current proxy at end
	if (defined($self->{proxy})) {
		$s_proxies->down();
		if ($limits_reached) {
			$self->{proxy}->{downloads} = 0;
			push(@proxies, $self->{proxy}) unless $config->get("delete");
		} else {
			push(@proxies, $self->{proxy});
		}
		$s_proxies->up();
	}
	
	# Pick next proxy
	$s_proxies->down();
	if ($config->get("order") eq "random") {
		my $index = rand(scalar(@proxies));
		$self->{proxy} = delete($proxies[$index]);
		
		# Fix the "undef" gap delete creates (variant which preserves order)
		# (which does not happen if "delete" deleted last element)
		if ($index != scalar(@proxies)) {
			$proxies[$index] = shift(@proxies);
		}
	} elsif ($config->get("order") eq "linear") {
		$self->{proxy} = shift(@proxies);
	} else {
		$s_proxies->up();
		return error("unrecognized proxy order '", $config->get("order"), "'");
	}
	$s_proxies->up();
	
	$self->set();
}

# Activate a proxy
sub set($) {
	my ($self) = @_;
	
	# Select proxy if available
	if (defined($self->{proxy})) {
		info("using proxy '", $self->{proxy}->{link}, "' for protocols ", join(" and ", @{$self->{proxy}->{protocols}}));
		$self->{ua}->proxy($self->{proxy}->{protocols}, $self->{proxy}->{link});
		return 1;
	} else {
		info("disabled proxies");
		$self->{ua}->no_proxy();
		return 0;
	}
}

# Return
1;


#
# Documentation
#

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

