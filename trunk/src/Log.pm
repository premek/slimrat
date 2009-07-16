# slimrat - log messages infrastructure
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
package Log;

# Packages
use Term::ANSIColor qw(:constants);

# Custom packages
use Configuration;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(bytes_readable level debug info warning error usage fatal progress summary status wait);

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->add_default("screen", 1);
$config->add_default("screen_verbosity", 3);
$config->add_default("screen_mode", "full");
$config->add_default("file", 1);
$config->add_default("file_path", $ENV{HOME} . "/.slimrat/log");
$config->add_default("file_verbosity", 3);
$config->add_default("file_mode", "log");

# Configure the package
sub configure {
	my $complement = shift;
	$config->merge($complement);
}


#
# Internal functions
#

# Print a message
sub output_raw {
	my ($filehandle, $colour, $timestamp, $category, $messages, $verbosity) = @_;
	
	print $filehandle $colour if ($colour);
	print $filehandle $timestamp?&timestamp:(" " x length(&timestamp));
	print $filehandle uc($category).": " if ($category);
	print $filehandle $_ foreach (@{$messages});
	print $filehandle RESET if ($colour);
	print $filehandle "\n";
}

# Print a message
sub output {
	my ($colour, $timestamp, $category, $messages, $verbosity) = @_;
	
	# Screen output
	if ($config->get("screen") && $config->get("screen_verbosity") >= $verbosity) {
		my @args = @_;
		$args[0] = "" if ($config->get("screen_mode") eq "log");
		my $fh;
		open($fh, ">&STDOUT");
		output_raw($fh, @args);
		close($fh);
	}
	
	# File output
	if ($config->get("file") && $config->get("file_verbosity") >= $verbosity) {
		my @args = @_;
		$args[0] = "" if ($config->get("file_mode") eq "log");
		my $fh;
		open($fh, ">>".$config->get("file_path")) || die("could not open given logfile");
		output_raw($fh, @args);
		close($fh);	
	}
}


# Generate a timestamp
sub timestamp {
	my ($sec,$min,$hour) = localtime;
	sprintf "[%02d:%02d:%02d] ",$hour,$min,$sec;
}

# Convert a raw amount of bytes to a more human-readable form
sub bytes_readable
{
	my $bytes = shift;
	
	my $bytes_hum = "$bytes";
	if ($bytes>2**30) { $bytes_hum = ($bytes / 2**30) . " GB" }
	elsif ($bytes>2**20) { $bytes_hum = ($bytes / 2**20) . " MB" }
	elsif ($bytes>2**10) { $bytes_hum = ($bytes / 2**10) . " KB" }
	else { $bytes_hum = $bytes . " B" }
	$bytes_hum =~ s/(^\d{1,}\.\d{2})(\d*)(.+$)/$1$3/;
	
	return $bytes_hum;
}


#
# Enhanced print routines
#	

# Debug message
sub debug {
	output(GREEN, 1, "debug", \@_, 4);
	return 0;
}

# Informative message
sub info {
	output("", 1, "", \@_, 3);
	return 0;
}

# Warning
sub warning {
	output(YELLOW, 1, "warning", \@_, 2);
	return 0;
}

# Non-fatal error
sub error {
	output(RED, 1, "error", \@_, 1);
	return 0;
}

# Usage error
sub usage {
	output(YELLOW, 1, "invalid usage", \@_, 0);
	output("", 1, "", ["Try `$0 --help` or `$0 --man` for more information"]);
	main::quit();
}

# Fatal runtime error
sub fatal {
	output(RED, 1, "fatal error", \@_, 0);
	main::quit();
}


#
# Complex Slimrat-specific routines
#

# Progress bar (TODO: ETA + screen|file_mode)
sub progress {
	my ($done, $total, $time) = @_;
	if ($total) {
		my $perc = $done / $total;
		print "\r", &timestamp, "Downloaded: ", int($perc*10000)/100, "%      ";
	} else {
		print "\r", &timestamp, "Downloaded ", bytes_readable($done);
	}
}

# Download summary
sub summary {
	my $ok_ref = shift;
	my @oklinks = @{$ok_ref};
	my $fail_ref = shift;
	my @faillinks = @{$fail_ref};
	
	if (scalar(@oklinks) + scalar(@faillinks)) {
		info("Download summary:");
	} else {
		return 0;
	}
	
	if(scalar @oklinks){
		output(GREEN, 0, "", ["DOWNLOADED:"], 3);
		output("", 0, "", ["\t", $_], 3) foreach @oklinks;
	}
	if(scalar @faillinks){
		output(RED, 0, "", ["FAILED:"], 3);
		output("", 0, "", ["\t", $_], 3) foreach @faillinks;
	}
}

# Status of a download link
sub status {
	my $link = shift;
	my $status = shift;
	my $extra = shift;

	if ($status>0) {
		output(GREEN, 0, "", ["[ALIVE] ", RESET, $link, " ($extra)"], 3);
	} elsif ($status<0) {
		output(RED, 0, "", ["[DEAD] ", RESET, $link, " ($extra)"], 3);
	} else {
		output(YELLOW, 0, "", ["[?] ", RESET, $link, " ($extra)"], 3);
	}
}


#
# Other
#

# Wait a while
sub wait {
	my ($wait, $rem, $sec, $min);
	$wait = $rem = shift or return;
	($sec,$min) = localtime($wait);
	info(sprintf("Waiting %d:%02d",$min,$sec));
	sleep($rem);
}

# Return
1;

__END__

=head1 NAME 

Log

=head1 SYNOPSIS

  use Log;

  # Print some messages
  info("this is a informational message");
  warning("something bad is going to happen");
  fatal("and here it is");
  error("this poor error will never be shown");
  quit();

  # Define a quit method (used by the fatal() function)
  sub quit() {
    exit(0);
  }

=head1 DESCRIPTION

This package provides several functions to ease messaging the
user. It differentiates several verbosity levels, and provides
functions to log multiple types of messages. Messages get print
or hidden depending to a globally set verbosity level.

=head1 METHODS

=head2 output($colour, $timestamp, $category, \@messages, $verbosity))

This is the main function of the Log module, but mustn't be used directly. It prints
a set of messages, prefixed by $colour (to colourize the message), and optionally
adds in a category notice (e.g. DEBUG, or FATAL ERROR) after having it uppercased.
The message can get hidden when the verbosity is greater than the configured
verbosity level. The $timestamp value controls whether a timestamp is printed, when
absent spaces pad the message to line it out ($timestamp=0 is thus ideally for
a multiline message).

=head2 timestamp()

This generates a timestamp, and is also mainly intended for internal use by the
output() function.

=head2 level($level)

This sets the application-wide verbosity level, in which a higher level will print
more, and a lower level less (see the actual message functions to see which type of
message each level correlates with).

=head2 debug(@messages)

This prints all passed arguments as a debug message in a green colour. Verbosity level
has to be 4 or more.

=head2 info(@messages)

This prints all passed arguments as an informational message in the standard colour.
Verbosity level has to be 3 or more. This is the main function for user-output.

=head2 warning(@messages)

This prints all passed arguments as a warning in a red colour. Verbosity level has
to be 2 or more. A warning indicates something awkward has happened, but it is not
severe and the program can continue working (e.g. a suspicious URL redirect).

=head2 error(@messages)

This prints all passed arguments as an error in a red colour. Verbosity level has
to be 1 or more. An error indicates something quite severe has happened, but is
not fatal and the program can continue working without much consequences (e.g.
a plugin has failed).

=head2 fatal(@messages)

This prints all passed arguments as a fatalerror in a red colour. Verbosity level has
to be 0 or more. Such an error indicates something severe has happened, and the
program cannot continue execution (e.g. configuration file not found). This routine
calls the main quit() function.

=head2 progress($done, $total, $time)

This generates a evolving progress bar, which expresses the current progress ($done)
to the final target ($total). An ETA is generated based on the $time needed to get
to the current progress.

=head2 summary($succeeded, $failed)

This prints a download summary, given two refs to arrays with actual links.

=head2 status($link, $status, $extra)

Print a one-line status indication for a given download URL, with some extra information
between brackets.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

