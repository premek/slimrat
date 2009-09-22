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
use Carp qw(confess);
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
@EXPORT = qw(level debug info warning error usage fatal progress summary status dump_add dump_write set_debug callstack_confess);

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("verbosity", 3);
$config->set_default("screen", 1);
$config->set_default("file", 1);
$config->set_default("file_path", $ENV{HOME} . "/.slimrat/log");
$config->set_default("dump_folder", "/tmp");
$config->set_default("show_thread", 0);

# Shared data
my @dumps:shared; my $s_dumps:shared = new Semaphore;
my $dump_output:shared = "";

# Progress length variable
my $progress_length = 0;

# Flags
# bit 1: last message was not finished by an endline (ie. progress())
my $flags : shared = 0;


#
# Internal functions
#

# Print a message
sub output_raw {
	my ($fh, $dataref) = @_;
	my %data = %$dataref;
	
	print $fh $data{colour} if $data{colour};
	print $fh $data{omit_timestamp}?(" " x length(&timestamp)):&timestamp;
	print $fh "THR", thread_id(), " " if ($config->get("show_thread") && $config->get("verbosity") > 4);
	print $fh uc($data{category}).": " if $data{category};
	print $fh $_ foreach (@{$data{messages}});
	print $fh RESET if ($data{colour});
	print $fh "\n" unless ($data{omit_endline});
}

# Print a message
sub output : locked {
	my %data = @_;
	$data{colour} = "" unless defined($data{colour});
	$data{category} = "" unless defined($data{category});
	$data{omit_timestamp} = 0 unless defined($data{omit_timestamp});
	$data{omit_endline} = 0 unless defined($data{omit_endline});
	$data{omit_file} = 0 unless defined($data{omit_file});
	$data{verbosity} = 3 unless defined($data{verbosity});
	
	# Verbosity
	return unless ($config->get("verbosity") >= $data{verbosity});
	
	# Aesthetics: uppercase first character
	if (!$data{category}) {
		my @messages = @{$data{messages}};
		$messages[0] = ucfirst $messages[0];
		$data{messages} = \@messages;
	}
	
	# Aesthetics: endline handling
	if ($data{omit_endline}) {
		print "\r" if ($flags & 1);
		$flags |= 1;
	} else {
		print "\n" if ($flags & 1);
		$flags &= ~1;
	}
	
	# Screen output
	if ($config->get("screen")) {
		my $fh;
		open($fh, ">&STDOUT");
		output_raw($fh, \%data);
		close($fh);
	}
	
	# Delete colours
	delete($data{colour});
	
	# Debug log output when in --debug mode
	if ($config->get("verbosity") >= 5) {
		my ($fh, $temp);	# Perl doesn't like filehandles to shared variables (bug?)
		$temp = "";
		open($fh, ">>", \$temp);
		output_raw($fh, \%data);
		close($fh);
		$dump_output .= $temp;
	}
	
	# File output
	if (!$data{omit_file} && $config->get("file") && -d dirname($config->get("file_path")) && -w dirname($config->get("file_path"))) {
		my $fh;
		open($fh, ">>".$config->get("file_path")) || die("could not open given logfile");
		output_raw($fh, \%data);
		close($fh);	
	}
}


#
# Enhanced print routines
#	

# Debug message
sub debug {
	output(	colour => GREEN,
		category => "debug",
		messages => \@_,
		verbosity => 4
	);
	return 0;
}

# Print a callstack based on passed "confess" data
sub callstack_confess {
	my $confess = shift;
	my $offset = shift;
	my $traces = 0;
	
	while ($confess =~ s/\s*(.+)//) {
		if (--$offset == -1) {
			if ($1 =~ m/^.*(at .+)/) {
				output(	colour => GREEN,
					category => "debug",
					messages => ["call stack leading to instruction at $1:"],
					verbosity => 5
				);
			} else {
				output(	colour => GREEN,
					category => "debug",
					messages => ["call stack leading to last instruction:"],
					verbosity => 5
				);
			}
			next;
		} elsif ($offset >= -1) {
			next;
		}			
		$traces++;
		output(	colour => GREEN,
			category => "debug",
			omit_timestamp => 1,
			messages => ["\t", $1],
			verbosity => 5
		);
	}
	
	output(	colour => GREEN,
		category => "debug",
		omit_timestamp => 0,
		messages => ["\t", "(stack is empty)"],
		verbosity => 5
	) unless ($traces);
}

# Manually trace the callstack
sub callstack_manual {
	my $offset = shift || 0;
	my $traces = 0;
	
	output(	colour => GREEN,
			messages => ["manual call stack leading to instruction at package ", (caller(1))[0], " line ", (caller(1))[2], ":"],
			verbosity => 5
	);
	
	for (my $i = $offset; 1; $i++) {
		last unless (caller($i));
		$traces++;
		output(	colour => GREEN,
			category => "debug",
			omit_timestamp => 1,
			messages => ["\t", (caller($i))[3], ", called from package ", (caller($i))[0], " line ", (caller($i))[2]],
			verbosity => 5
		);		
	}
	
	output(	colour => GREEN,
		category => "debug",
		omit_timestamp => 0,
		messages => ["\t", "(stack is empty)"],
		verbosity => 5
	) unless ($traces);	
}

# Print a callstack
sub callstack {
	my $offset = shift || 0;
	
	# Strip "sub callstack" and eval in which "confess" happens
	$offset += 2;
	
	# Trace an error
	eval { confess( '' ) };
	if ($@) {
		# Strip 2 stack steps (sub callstack and signal handler)
		callstack_confess($@, $offset);
	}
	
	# Do a regular trace and hope the error happened in this thread
	else {
		callstack_manual($offset);
	}

}

# Informative message
sub info {
	output(messages => \@_);
	return 0;
}

# Progress indication (same verbosity as info, but omitted when mode=log)
sub progress {
	my $length = 0;
	$length += length($_) foreach (@_);
	my $erase = $progress_length-$length;
	$progress_length = $length;
	output(	messages => [@_, " " x $erase],	# Extra spaces act as eraser
			omit_endline => 1,
			omit_file => 1
	);
}

# Warning
sub warning {
	output(	colour => YELLOW,
			category => "warning",
			messages => \@_,
			verbosity => 2
	);
	return 0;
}

# Non-fatal error
sub error {
	output(	colour => RED,
			category => "error",
			messages => \@_,
			verbosity => 1
	);
	callstack(1);	# Strip "sub error"
	return 0;
}

# Usage error
sub usage {
	output(	colour => YELLOW,
			category => "invalid usage",
			messages => \@_,
			verbosity => 0
	);
	output(	omit_timestamp =>  1,
			messages => ["Try `$0 --help` or `$0 --man` for more information"],
			verbosity => 0
	);
	
	# Quit
	if (defined(&main::quit)) {
		main::quit(255);
	} else {
		exit(255);
	}
}

# Fatal runtime error
sub fatal {
	output(	colour => RED,
			category => "fatal error",
			messages => \@_,
			verbosity => 0
	);
	callstack(1);	# Strip "sub fatal"
	
	# Quit
	if (defined(&main::quit)) {
		main::quit(255);
	} else {
		exit(255);
	}
}

# Warn
$SIG{__WARN__} = sub {
	# Deactivate handlers when parsing (undef) or eval'ing (1, except when in thread eval context [TODO: does not work])
	return warn @_ if (!defined($^S) || ($^S == 1 && !defined(threads->self()->error())));
	
	# Split message
	my $args_str = join("\n", @_);
	my @args = split("\n", $args_str);
	chomp(@args);
	
	# Multiline output
	output(	colour => YELLOW,
		category => "warning signal",
		messages => [shift @args],
		verbosity => 2
	);
	while ($_ = shift @args) {
		next unless $_;
		output(	colour => YELLOW,
			omit_timestamp => 1,
			messages => [$_],
			verbosity => 2
		);
	}
	
	# Callstack
	callstack(2);
};

# Die
$SIG{__DIE__} = sub {
	# Deactivate handlers when parsing (undef) or eval'ing (1, except when in thread eval context [TODO: does not work])
	return die @_ if (!defined($^S) || ($^S == 1 && !defined(threads->self()->error())));
	
	# Split message
	my $args_str = join("\n", @_);
	my @args = split("\n", $args_str);
	chomp(@args);
	
	# Multiline output
	output(	colour => RED,
			category => "fatal signal",
			messages => [shift @args],
			verbosity => 1
	);
	while (shift @args) {
		next unless $_;
		output(	colour => RED,
				omit_timestamp => 1,
				messages => [$_],
				verbosity => 1
		);
	}
	
	# Callstack
	callstack(2);
	
	# Quit
	if (defined(&main::quit)) {
		main::quit(255);
	} else {
		exit(255);
	}
};



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
		info("download summary:");
	} else {
		return 0;
	}
	
	if(scalar @oklinks){
		output(	colour => GREEN,
				omit_timestamp => 1,
				messages => ["DOWNLOADED:"],
				verbosity => 3
		);
		output(	omit_timestamp => 1,
				messages => ["\t", $_]
		) foreach @oklinks;
	}
	if(scalar @faillinks){
		output(	colour => RED,
				omit_timestamp => 1,
				messages => ["FAILED:"]
		);
		output(	omit_timestamp => 1,
				messages => ["\t", $_]
		) foreach @faillinks;
	}
}

# Status of a download link
sub status {
	my $link = shift;
	my $status = shift;
	my $extra = shift;
	$extra = " ($extra)" if $extra;

	if ($status>0) {
		output(	colour => GREEN,
				omit_timestamp => 1,
				messages => ["[ALIVE] ", RESET, $link, $extra]
		);
	} elsif ($status<0) {
		output(	colour => RED,
				omit_timestamp => 1,
				messages => ["[DEAD] ", RESET, $link, $extra]
		);
	} else {
		output(	colour => YELLOW,
				omit_timestamp => 1,
				messages => ["[?] ", RESET, $link, $extra]
		);
	}
}


#
# Other
#

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	
	$config->path_abs("file_path", "dump_folder");
}

# Set maximal verbostity without using configuration handler
sub set_debug() {
	$config->set_default("verbosity", 5);
}

# Quit the package
sub quit() {
	dump_write();
	print "\n" if ($flags & 1);
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
	debug("adding ", $dump->{type}, " dump ", (scalar(@dumps)+1));
	callstack(1);	# Strip "sub dump_add"
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
		my ($sec,$min,$hour,$mday,$mon,$year) = localtime($dump->{time}); $year+=1900;
		print INFO "\t- Created at ", (sprintf "%04d-%02d-%02d %02d:%02d:%02d",$year,$mon,$mday,$hour,$min,$sec), "\n";
		my $filename = $counter . "." . $dump->{type};
		print INFO "\t- Extra information: " . $dump->{extra} . "\n" if $dump->{extra};
		print INFO "\t- Saved as: $filename\n";
		print INFO "\n";
		
		# Save (TODO: type bin?)
		if ($dump->{type} =~ m/(htm|css|log|txt|pl|pm)/) {
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

=head2 Log::output(%data)

This is the main function of the Log module, but shouldn't be used directly.
It prints a set of messages, prefixed by $data{$colour} (to colourize the
message), and optionally adds in the category notice $data{category} (e.g.
DEBUG, or FATAL ERROR) after having it uppercased.
The message can get hidden when the verbosity $data{verbosity} is greater
than the configured verbosity level. The $data{omit_timestamp} value controls
whether a timestamp is printed, when set spaces pad the message to line it out.
$data{omit_endline} can be used to prevent to construct progress bars.
Similarly, omit_file should be set if a certain output should not be written
to the log file (e.g. progress indications, which cannot be overwritten
using \r and would clutter the log file).

Summarized, all possible options to this method:
   colour
   verbosity
   messages
   category
   omit_timestamp
   omit_endline
   omit_file

=head2 Log::timestamp()

This generates a timestamp, and is also mainly intended for internal use by the
output() function.

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

