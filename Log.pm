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
@EXPORT = qw(timestamp debug info warning error fatal);

# Write nicely
use strict;
use warnings;


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

# Debug message
sub debug {
	output(GREEN, "debug", \@_);
	return 0;
}

# Informative message
sub info {
	output(RESET, \@_);
	return 0;
}

# Warning
sub warning {
	output(YELLOW, "warning", \@_);
	return 0;
}

# Non-fatal error
sub error {
	output(RED, "error", \@_);
	return 0;
}

# Fatal error
sub fatal {
	output(RED, "fatal", \@_);
	# TODO: call slimrat::quit
	die();
}

# Return
1;

