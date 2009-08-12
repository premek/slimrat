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
our $VERSION = '1.0.0-trunk';

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(config_verbosity config_readfiles config_other config_cli config_gui get_guicfg daemonize pid_read download $mech);	# TODO: export of $mech shouldn't be neccesary, move all Plugin->new calls to Common?

# Packages
use POSIX 'setsid';
use Time::HiRes qw(time);
use URI;
use Compress::Zlib;
use File::Temp qw/tempfile/;

# Custom packages
use Configuration;
use Log;
use Plugin;

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Write nicely
use strict;
use warnings;

# Main configuration object
my $config = new Configuration;
$config->set_default("state_file", $ENV{HOME}."/.slimrat/pid");
$config->set_default("timeout", 10);
$config->set_default("useragent", "slimrat/$VERSION"); # or (WWW::Mechanize::known_agent_aliases())[0]  ???

# Browser
our $mech = WWW::Mechanize->new(autocheck => 0);
#$mech->default_header('Accept-Encoding' => ["gzip", "deflate"]); # TODO: fix encoding
$mech->default_header('Accept-Language' => "en");
$mech->agent($config->get("useragent")); # TODO : config files not readed yet, default value cannot be overwritten
$mech->timeout($config->get("timeout"));


# Proxy manager
my $proxy = new Proxy($mech);



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
	foreach my $file ("/etc/slimrat.conf", $ENV{HOME}."/.slimrat/config", shift) {
		if ($file && -r $file) {
			$config->file_read($file);
			#debug("Reading config file '$file'"); # Log verbosity not configured yet
			#print "reading $file\n";
		}
	}
}

sub config_other {
	# Configure the output
	Log::configure($config->section("log"));

	# Configure the plugin producer
	Plugin::configure($config);
	
	# Configure the proxy manager
	Proxy::configure($config->section("proxy"));
	
	# Make sure slimrat has a proper directory in the users home folder
	if (! -d $ENV{HOME}."/.slimrat") {
		if(-f $ENV{HOME}."/.slimrat" && rename $ENV{HOME}."/.slimrat", $ENV{HOME}."/.slimrat.old"){
			warning("File '".$ENV{HOME}."/.slimrat' renamed to '".$ENV{HOME}."/.slimrat.old'. This file from old version is not needed anymore. You can probably delete it."); 
		}
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
sub download($$$$) {
	my ($link, $to, $progress, $captcha_user_read) = @_;
	
	info("Downloading ", $link);
	if ($link =~ /^(.+):\/\//) {
		$proxy->advance($1);
	} else {
		warning("could not deduce protocol, proxies might not work correctly");
	}

	# Load plugin
	my $plugin = Plugin->new($link, $mech) || return 0;
	my $pluginname = $plugin->get_name();

	debug("Downloading \"$link\" using the $pluginname-plugin");
	
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
	my $done_prev = 0;
	my $size_downloaded = 0;
	
	# Get data
	my $encoding;
	my $encoding_extra;
	my $flag = 0;
	my $ocrcounter = 0;
	$|++; # unbuffered output
	# store (and later return) return value of get_data()
	my $plugin_result = $plugin->get_data( sub {
		# Fetch server response
		my $res = $_[1];

		# Do one-time stuff
		unless ($flag) {		
			# Get content encoding
			$encoding = $res->header("Content-Encoding");
			debug("content-encoding is $encoding") if $encoding;
			
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
				if ($res->headers->{'content-disposition'} && $res->headers->{'content-disposition'} =~ /filename="?([^"]+)"?$/i) {$filename = $1}
				else {$filename = (URI->new($res->request->uri)->path_segments)[-1]} # last segment of URI
				if(!$filename) {$filename = "SLIMRAT_DOWNLOADED_FILE";}
			}

			$filename =~ s/([^a-zA-Z0-9_\.\-\+\~])/_/g; 
			$to =~ s/\/+$//;
			$filepath = "$to/$filename";

			# Check if exists
			# add .1 at the end or increase the number if it is already there
			# TODO: maybe control with some config, e.g. "overwrite = no | yes | rename"
			$filepath =~ s/(?:\.(\d+))?$/".".(($1 or 0)+1)/e while(-e $filepath);
			info("File will be saved as \"$filepath\"");	

			# Open file
			open(FILE, ">$filepath");
			if (! -w FILE) {
				error("could not open file to write");
				goto ERROR;
			}
			binmode FILE;
			
			$flag = 1;
		}
		
		# Write the data
		if (!defined $encoding) {
			print FILE $_[0];		
		}
		elsif ($encoding eq "gzip") {
			my $data = Compress::Zlib::memGunzip($_[0]);
			if (!$data) {
				error("could not gunzip data: $!");
				goto ERROR;
			}
			print FILE $data;
		} elsif ($encoding eq "deflate") {
			if (!$encoding_extra) {
				$encoding_extra = inflateInit(WindowBits => - MAX_WBITS) || return error("could not setup inflation handler");
			}
			my ($output, $status) = $encoding_extra->inflate($_[0]);
			if ($status == Z_OK or $status == Z_STREAM_END) {
				print FILE $output;
			} else {
				error("inflation failed with status '$status': ", $encoding_extra->msg());
				goto ERROR; # TODO: is there a cleaner way to exit this sub? Return doesn't work, and die() quits
				            # the downloading as documented but makes it undetectable ($plugin_result is
				            # a HTTP::Resonse object as get_data didn't fail but correctly returns the result
				            # of the last statement)...
			}
		} else {
			error("unhandled content encoding '$encoding'");
			goto ERROR;
		}
		
		# Download indication
		$done_prev += length($_[0]);
		$size_downloaded += length($_[0]);	
		if ($t_prev+1 < time) {	# don't update too often
			&$progress($size_downloaded, $size, $done_prev, $t_prev?time-$t_prev:0);
			$done_prev = 0;
			$t_prev = time;
		}
	}, sub { # autoread captcha if configured, else let user read it
		my $captcha_data = shift;
		my $captcha_type = shift;
		my $captcha_value;		
		dump_add($captcha_data, "gif");
		
		# Dump data in temporary file
		my ($fh, $captcha_file) = tempfile(SUFFIX => ".$captcha_type");
		print $fh $captcha_data;
		
		# OCR
		if ($config->get("captcha_reader") && $ocrcounter++ < 5) {
			# Preprocess
			if ($plugin->can("ocr_preprocess")) {
				$plugin->ocr_preprocess($captcha_file);
			}
			
			# Convert if needed
			my $captcha_file_ocr = $captcha_file;
			if ($config->get("captcha_format") && $captcha_type ne $config->get("captcha_format")) {
				my $captcha_want = $config->get("captcha_format");
				my (undef, $captcha_converted) = tempfile(SUFFIX => ".$captcha_want");
				my $extra = $config->get("captcha_extra") || "";
				debug("converting captcha from $captcha_type:$captcha_file to $captcha_want:$captcha_converted");
				`convert $extra $captcha_type:$captcha_file $captcha_want:$captcha_converted`;
				if ($?) {
					error("could not convert captcha from given format $captcha_type to needed format $captcha_want, bailing out");
					goto USER;
				}
				$captcha_file_ocr = $captcha_converted;
			}
			
			# Apply OCR
			my $command = $config->get("captcha_reader");
			$command =~ s/\$captcha/$captcha_file_ocr/g;
			$captcha_value = `$command`;
			if ($?) {
				error("OCR failed");
				goto USER;
			}
			$captcha_value =~ s/\s+//g;
			debug("Captcha read by OCR: '$captcha_value'");
			
			# Postprocess
			if ($plugin->can("ocr_postprocess")) {
				$captcha_value = $plugin->ocr_postprocess($captcha_value);
				debug("Captcha after post-processing: '$captcha_value'");
			}
		}
		
		# User
		USER:
		$captcha_value = &$captcha_user_read($captcha_file) unless $captcha_value;
		
		return $captcha_value;
	});
	
	# Finish the progress bar
	if ($plugin_result) {	
		if ($size) {
			&$progress($size, $size, 0, 1);
		} else {
			&$progress($size_downloaded, 0, 0, 1);
		}
	}
	print "\r\n";
	
	# Close file
	close(FILE);
	
	# Return correctly
	return ($plugin_result?1:0);
	ERROR: return 0;
}

1;

