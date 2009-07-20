# Common.pm - Slimrat functionality shared between CLI and GUI
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
#    Přemek Vyhnal <premysl.vyhnal gmail com>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#################
# CONFIGURATION #
#################

# Package name
package Common;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(config_verbosity config_readfiles config_other config_cli config_gui get_guicfg daemonize download);

# Packages
use POSIX 'setsid';

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Custom packages
use Configuration;
use Log;
use Plugin;

# Write nicely
use strict;
use warnings;

# Main configuration object
my $config = new Configuration;
$config->set_default("state_file", $ENV{HOME}."/.slimrat/pid");



############
# ROUTINES #
############

#
# Configuration
#

sub config_verbosity {
	my $verbosity = shift;
	$config->section("log")->set("verbosity", $verbosity);
}

sub config_readfiles {
	# Read configuration files (this section should contain the _only_ hard coded paths, except for default values)
	if (-r "/etc/slimrat.conf") {
		$config->file_read("/etc/slimrat.conf");
	}
	if (-r $ENV{HOME}."/.slimrat/config") {
		$config->file_read($ENV{HOME}."/.slimrat/config");
	}
}

sub config_other {
	# Configure the output
	Log::configure($config->section("log"));

	# Configure the plugin producer
	Plugin::configure($config);
	
	# Make sure slimrat has a proper directory in the users home folder
	if (! -d $ENV{HOME}."/.slimrat") {
		debug("creating directory " . $ENV{HOME} . "/.slimrat");
		unless (mkdir $ENV{HOME}."/.slimrat") {
			fatal("could not create slimrat's home directory");
		}
	}
}

sub config_cli {
	return $config->section("cli");
}

sub config_gui {
	return $config->section("gui");
}


#
# Daemonisation
#

# Fork into the background
sub daemonize() {
	# Check current instances
	if (my $pidr = pid_read()) {
		if ($pidr && kill 0, $pidr) {	# Signal 0 doesn't do any harm
			fatal("an instance already seems to be running, please specify an alternative state file for this instance");
		}
	} else {
		warning("could not query state file to check for existing instances (harmless at first run)");
	}
	
	# Regular daemon householding
	chdir '/' or fatal("couldn't chdir to / ($!)");
	open STDIN, '/dev/null' or fatal("couldn't redirect input from /dev/null ($!)");
	
	# Create a child
	defined(my $pid = fork) or fatal("couldn't fork ($!)");
	exit if $pid;
	debug("child has been forked off at PID $$");
	
	# Start a new session
	setsid or fatal("couldn't start a new session ($!)");
	
	# Save the PID
	if (!pid_save()) {
		fatal("could not write the state file");
	}
	
	# Redirect all output
	info("Muting screen output, make sure a logfile has been configured to output to");
	$config->section("log")->set("screen", 0);
}

# Save the PID
sub pid_save() {
	my $state_file = $config->get("state_file");
	open(WRITE, ">$state_file") || return 0;	# Open and check existance
	return 0 unless (-w WRITE);			# Check write access
	print WRITE $$;
	close(WRITE);
	return 1;
}

# Extract an PID
sub pid_read() {
	# Check existance and read access
	my $state_file = $config->get("state_file");
	return 0 unless (-f $state_file && -r $state_file);
	
	# Read PID
	open(PIDR, $state_file);
	my $pid = <PIDR> || return 0;
	close(PIDR);
	
	return 0 if ($pid !~ /^\d+$/);	
	return $pid;
}


#
# Downloading
#

# Redirect download() call to the correct plugin
sub download($$$) {
	my ($link, $to, $progress) = @_;
	
	# Load plugin
	my $plugin = Plugin->new($link) || return 0;
	my $pluginname = $plugin->get_name();
	debug("downloading \"$link\" using the $pluginname-plugin");
	
	# Check if link is valid
	my $status = $plugin->check();
	if ($status < 0){
		error("check failed (dead link)");
		return $status;
	}
	elsif ($status == 0) {
		warning("check failed (unknown reason)");
		return $status;
	}

	# Check if we can write to "to" directory
	return error("Directory '$to' not writable") unless (-d $to && -w $to);
	
	# Get destination filename
	my $filename = $plugin->get_filename();
	my $filepath;


	# Download status counters
	my $size;
	my $t_start = time;
	my $t_prev = 0;
	my $size_downloaded = 0;
	
	# Get data
	my $flag = 0;
	$|++; # unbuffered output
	# store (and later return) return value of get_data()
	my $plugin_result = $plugin->get_data( sub {	# TODO: catch errors
		# Fetch server response
		my $res = $_[1];

		# Do one-time stuff
		unless ($flag) {

			# Save length and print
			$size = $res->content_length;
			if ($size)
			{
				info("Filesize: ", bytes_readable($size));
			} else {
				info("Filesize unknown");
			}

			# If plugin didn't tell us name of the file, we can get it from http response or request.
			if(!$filename) {
				if ($res->headers->{'content-disposition'} =~ /filename="?([^"]+)"?$/i) {$filename = $1}
				elsif($res->request->uri =~ m{/([^\/]+?)((\?|#).*)?$}) {$filename = $&}
				else {$filename = "slimrat_downloaded_file";}
			}

			$to .= '/' if ($to !~ m{/$});
			$filepath = $to . $filename;

			# Check if exists
			# add .1 at the end or increase the number if it is already there
			$filepath =~ s/(?:\.(\d+))?$/".".(($1 or 0)+1)/e while(-e $filepath);

			info("File will be saved as \"$filepath\"");
	

			# Open file
			open(FILE, ">$filepath") or return error("could not open file to write"); 
			binmode FILE;
			
			$flag = 1;
		}
		
		# Write the data
		print FILE $_[0];
		
		# Download indication
		$size_downloaded += length($_[0]);	
		if ($t_prev+1 < time) {	# don't update too often
			$t_prev = time;
			&$progress($size_downloaded, $size, 0);
		}
	});
	if ($size) {
		&$progress(1, 1, 0);
	} else {
		&$progress($size_downloaded, 0, 0);
	}
	print "\r\n";
	
	# Close file
	close(FILE);
	
	# Download finished
	info("File downloaded") if $plugin_result;
	return $plugin_result;
}

1;

