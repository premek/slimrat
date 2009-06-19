#!/usr/bin/env perl
#
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

# Modules
use Term::ANSIColor qw(:constants);

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(timestamp debug info warning error usage fatal level);

# Write nicely
use strict;
use warnings;

# Verbosity level
my $verbosity = 3;


#
# Internal functions
#

# Print a message
sub output {
	print shift, &timestamp, @_==2?uc(shift).": ":"";
	print while ($_ = shift(@{$_[0]}));
	print RESET, "\n";
}


# Generate a timestamp
sub timestamp {
	my ($sec,$min,$hour) = localtime;
	sprintf "[%02d:%02d:%02d] ",$hour,$min,$sec;
}


#
# Log routines
#

# Set loglevel
sub level($) {
	my $level = shift;
	$verbosity = $level;
}

# Debug message
sub debug {
	output(GREEN, "debug", \@_) if ($verbosity >= 4);
	return 0;
}

# Informative message
sub info {
	output(RESET, \@_) if ($verbosity >= 3);
	return 0;
}

# Warning
sub warning {
	output(YELLOW, "warning", \@_) if ($verbosity >= 2);
	return 0;
}

# Non-fatal error
sub error {
	output(RED, "error", \@_) if ($verbosity >= 1);
	return 0;
}

# Usage error
sub usage {
	output(YELLOW, "invalid usage", \@_) if ($verbosity >= 1);
	output(RESET, ["Try `$0 --help` or `$0 --man` for more information"]);
	main::quit();
}

# Fatal runtime error
sub fatal {
	output(RED, "fatal error", \@_) if ($verbosity >= 0);
	main::quit();
}

# Return
1;

__END__

=head1 NAME 

Log

=head1 SYNOPSIS

  use Log;

  # Set the verbosity level to 2 (only print warnings, errors or fatal errors)
  level(2);

  # Print some messages
  info("this is a informational message, hidden due to verbosity settings");
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

=head2 output($prefix, $optional_subject, \@messages)

This is the main function of the Log module, but mustn't be used directly. It prints
a set of messages, prefixed by $prefix (e.g. to colourize the message), and optionally
adds in a subject notice (e.g. DEBUG, or FATAL ERROR) after having it uppercased.

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

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

