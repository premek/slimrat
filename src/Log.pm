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
use Carp;
use threads;
use threads::shared;
use Term::ANSIColor qw(:constants);
use Cwd;
use File::Temp qw/tempdir/;
use File::Basename;

# Custom packages
use Toolbox;
use Semaphore;
use Configuration;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(level debug info warning error usage fatal progress summary status wait dump_add dump_write set_debug);

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("verbosity", 3);
$config->set_default("mode", "full");
$config->set_default("screen", 1);
$config->set_default("file", 1);
$config->set_default("file_path", $ENV{HOME} . "/.slimrat/log");
$config->set_default("dump_folder", "/tmp");

# Shared data
my @dumps:shared; my $s_dumps:shared = new Semaphore;
my $dump_output:shared = "";

# Progress length variable
my $progress_length = 0;


#
# Internal functions
#

# Print a message
sub output_raw {
	my ($filehandle, $colour, $timestamp, $category, $messages, $verbosity, $omit_endl) = @_;
	
	print $filehandle $colour if ($colour);
	print $filehandle $timestamp?&timestamp:(" " x length(&timestamp));
	print $filehandle uc($category).": " if ($category);
	defined $_ and print $filehandle $_ foreach (@{$messages});
	print $filehandle RESET if ($colour);
	print $filehandle "\n" unless ($omit_endl);
}

# Print a message
sub output : locked {
	my ($colour, $timestamp, $category, $messages, $verbosity, $omit_endl) = @_;
	
	# Verbosity
	return unless ($config->get("verbosity") >= $verbosity);
	
	# Mode
	my @args = @_;
	$args[0] = "" if ($config->get("mode") eq "log");
	
	# Screen output
	if ($config->get("screen")) {
		my $fh;
		open($fh, ">&STDOUT");
		output_raw($fh, @args);
		close($fh);
	}
	
	# Delete colours
	delete($args[0]);
	
	# Debug log output when in --debug mode
	if ($config->get("verbosity") >= 5) {
		my ($fh, $temp);	# Perl doesn't like filehandles to shared variables (bug?)
		$temp = "";
		open($fh, ">>", \$temp);
		output_raw($fh, @args);
		close($fh);
		$dump_output .= $temp;
	}
	
	# File output
	if ($config->get("file") && -d dirname($config->get("file_path")) && -w dirname($config->get("file_path"))) {
		my $fh;
		open($fh, ">>".$config->get("file_path")) || die("could not open given logfile");
		output_raw($fh, @args);
		close($fh);	
	}
}


#
# Enhanced print routines
#	

# Debug message
sub debug {
	output(GREEN, 1, "debug", \@_, 4);
	return 0;
}

# Print a callstack
sub callstack {
	my $offset = shift || 0;
	output(GREEN, 1, "", ["Call stack:"], 5);
	
	# Get calltrace
	local $@;
	eval { confess('') };
	my $callstack = $@;
	
	# Print relevant calls
	while ($callstack =~ s/\s*(.+)//) {
		next if (--$offset >= -3);
		output(GREEN, 0, "", [$1], 5);
	}
}

# Informative message
sub info {
	output("", 1, "", \@_, 3);
	return 0;
}

# Progress indication (same verbosity as info, but omitted when mode=log)
sub progress {
	my $length = 0;
	$length += length($_) foreach (@_);
	my $erase = $progress_length-$length;
	$progress_length = $length;
	output("", 0, "", ["\r", &timestamp, @_, " " x $erase], 3, 1) unless ($config->get("mode") eq "log");	# Extra spaces act as eraser
}

# Warning
sub warning {
	output(YELLOW, 1, "warning", \@_, 2);
	return 0;
}

# Non-fatal error
sub error {
	output(RED, 1, "error", \@_, 1);
	callstack(1);
	return 0;
}

# Usage error
sub usage {
	output(YELLOW, 1, "invalid usage", \@_, 0);
	output("", 1, "", ["Try `$0 --help` or `$0 --man` for more information"], 0);
	if (defined(&main::quit)) {
		main::quit(255);
	} else {
		#exit(255);
	}
}

# Fatal runtime error
sub fatal {
	output(RED, 1, "fatal error", \@_, 0);
	callstack(1);
	if (defined(&main::quit)) {
		main::quit(255);
	} else {
		#exit(255);
	}
}



#
# Complex Slimrat-specific routines
#

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
	$extra = " ($extra)" if $extra;

	if ($status>0) {
		output(GREEN, 0, "", ["[ALIVE] ", RESET, $link, $extra], 3);
	} elsif ($status<0) {
		output(RED, 0, "", ["[DEAD] ", RESET, $link, $extra], 3);
	} else {
		output(YELLOW, 0, "", ["[?] ", RESET, $link, $extra], 3);
	}
}


#
# Other
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
}

# Set maximal verbostity without using configuration handler
sub set_debug() {
	$config->set_default("verbosity", 5);
}

# Quit the package
sub quit() {
	dump_write();
}

# Wait a while
sub wait {
	my $wait = shift or return;
	info(sprintf("Waiting ".seconds_readable($wait)));
	sleep($wait);
}

# Dump data for debugging purposes
sub dump_add {
	my %information = @_;
	return unless ($config->get("verbosity") >= 5);
	
	# Fill some possible gaps
	$information{data} = "" unless ($information{data});	# Replace potential undef to avoid warn()
	$information{type} = "html" unless ($information{type});
	$information{title} = "unnamed dump" unless ($information{title});	
	
	# Create shared hash for dump data
	my $dump;
	share($dump);
	$dump = &share({});
	
	# Save dump
	foreach my $key (keys %information) {
		$dump->{$key} = $information{$key};
	}
	$dump->{time} = time;
	$dump->{hierarchy} = (caller(1))[3] . ", line " . (caller(0))[2];
	debug("adding ", $dump->{type}, " dump ", (scalar(@dumps)+1), " from ", $dump->{hierarchy});
	$s_dumps->down();
	push @dumps, $dump;
	$s_dumps->up();
}

# Write the dumped data
sub dump_write() {
	return unless ($config->get("verbosity") >= 5);
	
	# Generate a tag and temporary folder
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
	$year += 1900;
	my $filename = "slimrat_dump_" . (sprintf "%04d-%02d-%02dT%02d-%02d-%02d",$year,$mon,$mday,$hour,$min,$sec);
	my $tempfolder = tempdir ( $filename."_XXXXX", TMPDIR => 1 );
	
	# Dump the actual log
	dump_add(title => "slimrat log", data => $dump_output, type => "log");
	
	# Dump files
	debug("dumping " . scalar(@dumps) . " file(s) to disk in temporary folder '$tempfolder'");	
	open(INFO, ">$tempfolder/info");
	my $counter = 1;
	$s_dumps->down();
	foreach my $dump (@dumps) {
		print INFO $counter, ") ", $dump->{title}, "\n";
		print INFO "\t- Called from: ", $dump->{hierarchy}, "\n";
		my ($sec,$min,$hour,$mday,$mon,$year) = localtime($dump->{time}); $year+=1900;
		print INFO "\t- Created at ", (sprintf "%04d-%02d-%02d %02d:%02d:%02d",$year,$mon,$mday,$hour,$min,$sec), "\n";
		my $filename = $counter . "." . $dump->{type};
		print INFO "\t- Extra information: " . $dump->{extra} . "\n" if $dump->{extra};
		print INFO "\t- Saved as: $filename\n";
		print INFO "\n";
		
		# Save (TODO: type bin?)
		if ($dump->{type} =~ m/(htm|css|log|txt)/) {
			open(DATA, ">:utf8", "$tempfolder/$filename");
		} else {
			open(DATA, ">", "$tempfolder/$filename");
		}
		print DATA $dump->{data};
		close(DATA);
		
		$counter++;
	}
	$s_dumps->up();
	close(INFO);
	
	# Generate archive	
	$filename .= ".tar.bz2";
	debug("compressing dump to '" . $config->get("dump_folder") . "/$filename'");
	my $cwd = getcwd;
	chdir($tempfolder) || return error("could not chdir to dump directory");
	system("tar -cjf \"" . $config->get("dump_folder") . "/$filename\" *") && return error("could not create archive");
	chdir($cwd);
}


#
# Signals
#

# Warn
$SIG{__WARN__} = sub {
	my @arg = @_;
	chomp($arg[-1]);
	error(@arg);
	return 1;
};

# Die
$SIG{__DIE__} = sub {
	my @arg = @_;
	chomp($arg[-1]);
	fatal(@arg);
};


# Return
1;


#
# Documentation
#

=head1 NAME 

Log

=head1 SYNOPSIS

  use Log;

  # Print some messages
  info("this is a informational message");
  warning("something bad is going to happen");
  fatal("and here it is");
  error("this poor error will never be shown");
  quit(1);

  # Define a quit method (used by the fatal() function)
  sub quit($) {
    exit(shift);
  }

=head1 DESCRIPTION

This package provides several functions to ease messaging the
user. It differentiates several verbosity levels, and provides
functions to log multiple types of messages. Messages get print
or hidden depending to a globally set verbosity level.

=head1 METHODS

=head2 Log::configure($config)

Merges the local base config with a set of user-defined configuration
values. This is a static method, and saves the configuration statically,
which means it applies to all (have been and to be) instantiated objects.

=head2 Log::output($colour, $timestamp, $category, \@messages, $verbosity))

This is the main function of the Log module, but mustn't be used directly. It prints
a set of messages, prefixed by $colour (to colourize the message), and optionally
adds in a category notice (e.g. DEBUG, or FATAL ERROR) after having it uppercased.
The message can get hidden when the verbosity is greater than the configured
verbosity level. The $timestamp value controls whether a timestamp is printed, when
absent spaces pad the message to line it out ($timestamp=0 is thus ideally for
a multiline message).

=head2 Log::timestamp()

This generates a timestamp, and is also mainly intended for internal use by the
output() function.

=head2 Log::level($level)

This sets the application-wide verbosity level, in which a higher level will print
more, and a lower level less (see the actual message functions to see which type of
message each level correlates with).

=head2 Log::debug(@messages)

This prints all passed arguments as a debug message in a green colour. Verbosity level
has to be 4 or more.

=head2 Log::info(@messages)

This prints all passed arguments as an informational message in the standard colou

=head2 Log::progress(@messages)

Print a progress indicating message. Before the messages are printed, the cursor is moved
back to the begin of the line by printing a carriage return. This feature combined with
messages not ending on an endline, is a good way to display some progress indication, in
which every progress() call overwrites the previously progress indication (unless an
endline has been appended).
The message does not get print if the output mode is "log" rather than "full".

=head2 Log::warning(@messages)

This prints all passed arguments as a warning in a red colour. Verbosity level has
to be 2 or more. A warning indicates something awkward has happened, but it is not
severe and the program can continue working (e.g. a suspicious URL redirect).

=head2 Log::error(@messages)

This prints all passed arguments as an error in a red colour. Verbosity level has
to be 1 or more. An error indicates something quite severe has happened, but is
not fatal and the program can continue working without much consequences (e.g.
a plugin has failed).

=head2 Log::fatal(@messages)

This prints all passed arguments as a fatalerror in a red colour. Verbosity level has
to be 0 or more. Such an error indicates something severe has happened, and the
program cannot continue execution (e.g. configuration file not found). This routine
calls the main quit() function.

=head2 Log::summary($succeeded, $failed)

This prints a download summary, given two refs to arrays with actual links.

=head2 Log::status($link, $status, $extra)

Print a one-line status indication for a given download URL, with some extra information
between brackets.

=head2 Log::dump_add($data, $extra, $type)

Adds data to the dump cache, which will later on be saved in a file ending on $type. Disabled
when the "dumps" config variable is not set. $extra indicates extra information and can be
omitted, as well as $type which then defaults to "html".

=head2 Log::dump_write()

Writes the dump cache to a persistent file. Firstly a temporary folder is created in /tmp in which
all files get dumped, after which "tar" and "bzip2" are used to compress the folder and place the
resulting file in a directory specified by the "dumps_folder" variable. Disabled when "dumps" variabele
not set. Temporary folder does not get removed, this should be the task of the OS upon reboot/shutdown.

=head1 AUTHOR

Tim Besard <tim-dot-besard-at-gmail-dot-com>

=cut

