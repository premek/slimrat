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

# Version information (NOTE: build nubmer is that of Common.pm)
our $VERSION = '1.0.0-trunk';
our $BUILD = '$Rev$';
$BUILD =~ s/^\$Rev: (\d+) \$$/$1/;

# Export functionality
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(config_init config_propagate config_browser configure daemonize pid_read download $THRCOMP);

# Packages
use Carp qw(confess);
use threads;
use threads::shared;
use Time::HiRes qw(sleep gettimeofday);
use POSIX 'setsid';
use Time::HiRes qw(time);
use URI;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;
use File::Temp qw/tempfile/;

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Custom packages
use Semaphore;
use Configuration;
use Log;
use Plugin;
use Toolbox;

# Write nicely
use strict;
use warnings;

# Main configuration object
my $config = new Configuration;
$config->set_default("state_file", $ENV{HOME}."/.slimrat/pid");
$config->set_default("timeout", 900);
$config->set_default("useragent", "slimrat/$VERSION");
$config->set_default("redownload", "rename");
$config->set_default("retry_count", 0);
$config->set_default("retry_wait", 60);
$config->set_default("ocr", 0);
$config->set_default("escape_filenames", 0);
$config->set_default("rate", undef);
$config->set_default("speed_window", 30);

# Shared data
my $downloaders:shared = 0;
my %rate_surplus:shared; my $s_rate_surplus = new Semaphore;

# Threads compatibility
our $THRCOMP = 0;
eval("use threads 1.34");
if ($@) {
	warning("your Perl version is outdated, thread might behave fishy");
	$THRCOMP = 1;
}

# Emit warning when using development version
warning("this is a development release (Common SVN build $BUILD), if you encounter any issues, please re-run slimrat with the '--debug' flag enabled, and submit the resulting dump file to the bug tracker");


############
# ROUTINES #
############

#
# Configuration
#

# Create a new configuration handler by reading the configuration files
sub config_init {	
	# Make sure slimrat has a proper directory in the users home folder
	if (! -d $ENV{HOME}."/.slimrat") {
		if(-f $ENV{HOME}."/.slimrat" && rename $ENV{HOME}."/.slimrat", $ENV{HOME}."/.slimrat.old"){
			warning("file '".$ENV{HOME}."/.slimrat' renamed to '".$ENV{HOME}."/.slimrat.old'. This file from old version is not needed anymore. You can probably delete it."); 
		}
		debug("creating directory " . $ENV{HOME} . "/.slimrat");
		unless (mkdir $ENV{HOME}."/.slimrat") {
			fatal("could not create slimrat's home directory");
		}
	}
	
	my $config = new Configuration;	
	foreach my $file ("/etc/slimrat.conf", $ENV{HOME}."/.slimrat/config", shift) {
		if ($file && -r $file) {
			debug("reading config file '$file'");
			$config->file_read($file);
		}
	}
	
	return $config;
}

# Merge a given main configuration handler with handlers from all subpackages
sub config_propagate {
	my $config = shift;
	
	Plugin::configure($config);
	Common::configure($config);
	Toolbox::configure($config->section("toolbox"));
	Log::configure($config->section("log"));
	Proxy::configure($config->section("proxy"));
	Queue::configure($config->section("queue"));
}

# Configure the package
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	
	# Check OCR dependancies
	if ($config->get("ocr")) {
		unless (`which tesseract` && `which convert`) {
			warning("disabling OCR functionality due to missing dependancies");
			$config->set("ocr", 0);
		}
	}
	
	$config->path_abs("state_file");
}

sub config_browser {
	my $mech = WWW::Mechanize->new(autocheck => 0, quiet => 1);
	$mech->default_header('Accept-Encoding' => ["identity", "gzip", "x-gzip", "x-bzip2", "deflate"]);
	$mech->default_header('Accept-Language' => "en");
	$mech->agent($config->get("useragent"));
	$mech->timeout($config->get("timeout"));
	return $mech;
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
	pid_save() or fatal("could not write the state file");
	
	# Redirect all output
	info("muting screen output, make sure a logfile has been configured to output to");
	$config->section("log")->set("screen", 0);
}

# Save the PID
sub pid_save() {
	my $state_file = $config->get("state_file");
	open(WRITE, ">$state_file") || return 0;	# Open and check existance
	return 0 unless (-w WRITE);	# Check write access
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
# Exception handling
#

# This code is based on Try::Tiny 0.02, by Yuval Kogman (nothingmuch@woobling.org),
# which is conveniently also MIT-licensed.

# Try a given block of code
sub try (&;$) {
	my ($try, $catch) = @_;

	# We need to save this here, the eval block will be in scalar context due
	# to $failed
	my $wantarray = wantarray;

	my (@ret, $error, $callstack, $failed);

	{
		# Configure DIE handler to provide stack traces in $@ instead of only
		# the fatal error
		local $SIG{__DIE__} = sub {
			$_[0] =~ m/^(.+)\sat\s/;
			confess($1);
		};
		
		# Localize $@ to prevent clobbering of previous value by a successful
		# eval.
		local $@;

		# $failed will be true if the eval dies, because 1 will not be returned
		# from the eval body
		$failed = not eval {

			# evaluate the try block in the correct context
			if ( $wantarray ) {
				@ret = $try->();
			} elsif ( defined $wantarray ) {
				$ret[0] = $try->();
			} else {
				$try->();
			};

			return 1; # properly set $fail to false
		};

		# Copy $@ to $callstack, when we leave this scope local $@ will revert $@
		# back to its previous value
		$callstack = $@;
		
		# Parse the effective error out of the callstack
		($error) = $callstack =~ m/^(.+)\sat/; 
		
	}

	# At this point $failed contains a true value if the eval died even if some
	# destructor overwrite $@ as the eval was unwinding.
	if ( $failed ) {
		# If we got an error, invoke the catch block.
		if ( $catch ) {
			# This works like given($error), but is backwards compatible and
			# sets $_ in the dynamic scope for the body of $catch
			for ($error) {
				return $catch->($error, $callstack);
			}

			# In case when() was used without an explicit return, the for
			# loop will be aborted and there's no useful return value
		}

		return;
	} else {
		# No failure, $@ is back to what it was, everything is fine
		return $wantarray ? @ret : $ret[0];
	}
}

# Configure a block of code to be runned in case of errors
sub catch (&) {
	return $_[0];
}


#
# Downloading
#

# Redirect download() call to the correct plugin
# Possible return values (quite analogue to the plugin's check() function):
#   1 = download successfully completed
#   0 = download failed, for unknown reason
#   -1 = download failed because URL is dead
#   -2 = plugin error
sub download {
	my ($mech, $link, $to, $progress, $captcha_userreader, $no_lock) = @_;
	$no_lock = 0 unless defined($no_lock);
	info("downloading '$link'");
	
	# Shared values
	my $counter = $config->get("retry_count");
	my $result;
	
	
	# CONSTRUCTION #
	# TODO: ditch the GOTO's, and make it loop-based using $counter and $result
	# TODO: maybe restrict retry handling to getdata?
	CONSTRUCTION:
	my $plugin;
	
	$result = try {
		$plugin = download_init($link, $mech, $no_lock);
		
		return 1;
	}
	catch {
		my ($error, $callstack) = @_;
		error([$callstack, 1], "download failed while constructing ($error)");
		
		# Retry
		if ($counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto CONSTRUCTION;
		}
		
		return;
	};
	return -2 unless defined($result);
		
	# Return -3 if the caller requested to manage insufficient resources hisself
	# FIXME: yeah this sucks, I know
	if ($no_lock && $plugin == -1) {
		return -3;
	}
	
	
	# CHECK #
	CHECK:
	my $status;
	
	$result = try {		
		# Check the URL
		$status = $plugin->check();
		
		return 1;
	}
	catch {
		my ($error, $callstack) = @_;
		error([$callstack, 1], "download failed while checking ($error)");
		
		# Retry
		if ($counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto CHECK;
		}
		
		return;
	};
	return -2 unless defined($result);

	warning("check failed (unknown reason)") if ($status == 0);	
	error("check failed (dead link)") if ($status < 0);
	return $status if ($status < 0);
	

	# PREPARATION #
	PREPARATION:
	my ($filepath, $size_downloaded);
	
	$result = try {		
		($filepath, $size_downloaded) = download_prepare($plugin, $to);
		
		return 1;
	}	
	catch {
		my ($error, $callstack) = @_;
		error([$callstack, 1], "download failed while preparing ($error)");
		
		# Retry
		if ($counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto PREPARATION;
		}
		
		return;
	};
	return -2 unless defined($result);
	
	
	# GET DATA #
	GETDATA:
	
	$result = try {
		download_getdata($mech, $plugin, $filepath, $size_downloaded, $progress, $captcha_userreader);
		
		return 1;
	}	
	catch {
		my ($error, $callstack) = @_;
		error([$callstack, 1], "download failed while getting getting data ($error)");
		
		# Retry without resume: some servers (rapidshare...) go nuts when requesting a
		#   range. Don't ask me why they still advertise the RANGE capability...
		if ($size_downloaded != 0) {
			info("failure upon attempt to resume, retrying without attempting to resume");
			$size_downloaded = 0;
			goto GETDATA;
		}
		
		# Retry
		if ($counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto GETDATA;
		}
		
		return;
	};
	return -2 unless defined($result);
	
	# Close file
	close(FILE);	
}

sub download_init {
	# Input data
	my ($link, $mech, $no_lock) = @_;
	
	# Load plugin
	my $plugin = Plugin->new($link, $mech, $no_lock);
	
	# Return -3 if the caller requested to manage insufficient resources hisself	
	if ($no_lock && $plugin == -1) {
		return -3;
	}
	
	# Get plugin name
	my $pluginname = $plugin->get_name();
	debug("instantiated a $pluginname downloader");
	
	return $plugin;
}

sub download_prepare {
	# Input data
	my ($plugin, $to) = @_;
	
	# Check if we can write to the given directory
	die("directory '$to' not writable") unless (-d $to && -w $to);
	
	# Get destination filename
	my $filename = $plugin->get_filename();
	utf8::encode($filename);
	if (!$filename) {
		warning("could not deduce filename, falling back to default string");
		$filename = "SLIMRAT_DOWNLOADED_FILE";
	} elsif ($config->get("escape_filenames")) {
		$filename =~ s/([^a-zA-Z0-9_\.\-\+\~])/_/g; 
	}
	my $filepath = "$to/$filename";
	
	# Check if file exists
	my $size_downloaded = 0;
	if (-e $filepath) {
		my $action = $config->get("redownload");
		if ($action eq "overwrite") {
			info("file exists, overwriting");
			unlink $filepath;
		} elsif ($action eq "rename") {
			info("file exists, renaming");
			my $counter = 1;
			$counter++ while (-e "$filepath.$counter");
			$filepath .= ".$counter";
		} elsif ($action eq "skip") {
			info("file exists, skipping download");
			return 1;
		} elsif ($action eq "resume") {
			info("file exists, resuming");
			$size_downloaded = -s $filepath;
		} else {
			fatal("unrecognised action upon redownload");
		}
	}
	info("file will be saved as '$filepath'");
	
	return ($filepath, $size_downloaded);
}

sub download_getdata {
	# Input data
	my ($mech, $plugin, $filepath, $size_downloaded, $progress, $captcha_userreader) = @_;
	
	my $size;
	my $time_start = time;
	my $time_chunk = time;
	my $size_chunk;
	my $speed = 0;
	
	# Generate request header
	my @headers;
	if ($size_downloaded != 0) {
		push(@headers, Range => "bytes=" . $size_downloaded . "-");
	}
	
	# Get data
	my $encoding;
	my $encoding_extra;
	my $flag = 0;
	my $ocrcounter = 0;
	$|++; # unbuffered output
	$downloaders++;
	my $response;
	my %speed_chunks;
	
	# Get the data
	$response = $plugin->get_data(
		# Data processor
		sub {
			# Fetch server response
			my $res = $_[1];
	
			# Do one-time stuff
			unless ($flag) {
				# Check if server respected Range header
				if ($config->get("redownload") eq "resume" && $size_downloaded) {
					if ($res->code() == 206) {
						debug("Range request correctly aknowledged")	
					}
					elsif ($res->code() == 200) {	 # TODO: code 406, or if 200 and content-range?
						warning("server does not support resuming, restarting download");
						unlink $filepath;
						$size_downloaded = 0;
					}
				}
				
				# Get content encoding
				$encoding = $res->header("Content-Encoding");
				if ($encoding) {
				    $encoding =~ s/^\s+//;
				    $encoding =~ s/\s+$//;
					debug("content-encoding is $encoding");
					my @encodings = $mech->default_header('Accept-Encoding');
					for my $ce (reverse split(/\s*,\s*/, lc($encoding))) {
						if (indexof($ce, \@encodings) == -1) {
							die("cannot handle content-encoding '$encoding'");
						}
					}
				}
				
				# Save length and print
				$size = $res->content_length;
				if ($size)
				{
					$size += $size_downloaded;
					info("filesize: ", bytes_readable($size));
				} else {
					info("filesize unknown");
				}
	
				# Open file
				open(FILE, ">>$filepath");
				if (! -w FILE) {
					die("could not open file to write");
				}
				binmode FILE;
				
				$flag = 1;
			}
			
			# Write the data
			print FILE $_[0];
			
			# Counters		
			$size_chunk += length($_[0]);
			$size_downloaded += length($_[0]);
			my $dtime_chunk = gettimeofday() - $time_chunk;
			
			# Rate control
			if (defined(my $rate = $config->get("rate"))) {
				my $speed_cur = $size_chunk / $dtime_chunk;
				my $speed_aim = $rate * 1024 / $downloaders;
				$s_rate_surplus->down();
				delete($rate_surplus{thread_id()});
				$speed_aim += $rate_surplus{$_}/($downloaders-scalar(keys %rate_surplus)) foreach (keys %rate_surplus);
				$rate_surplus{thread_id()} = $speed_aim - $speed_cur if ($speed_aim-$speed_cur > 0);
				$s_rate_surplus->up();
				if ($speed_cur > $speed_aim) {
					sleep($size_chunk / $speed_aim - $dtime_chunk);
				}
				$dtime_chunk = gettimeofday()-$time_chunk;
			}
			
			# Download indication
			if ($time_chunk+1 < time) {	# don't update too often
				# Window handling
				$speed_chunks{thread_id()} = [] if (!defined($speed_chunks{thread_id()}));
				shift(@{$speed_chunks{thread_id()}}) while (scalar(@{$speed_chunks{thread_id()}}) > 0 and gettimeofday() - $speed_chunks{thread_id()}[0][0] > $config->get("speed_window"));
				push(@{$speed_chunks{thread_id()}}, [scalar(gettimeofday()), $size_chunk]);
				
				# Speed calculation
				if (scalar(@{$speed_chunks{thread_id()}}) > 1) {
					my $speed = 0;
					$speed += $_->[1] foreach (@{$speed_chunks{thread_id()}});
					$speed /= gettimeofday() - $speed_chunks{thread_id()}[0][0];
					
					# Calculate ETA
					my $eta = -1;
					$eta = ($size - $size_downloaded) / $speed if ($speed && $size);
					
					# Update progress
					&$progress($size_downloaded, $size, $speed, $eta);
				}
				
				# Reset counters for next chunk
				$size_chunk = 0;
				$time_chunk = gettimeofday();
			}
		},
		
		# Captcha processor
		sub {
			my $captcha_data = shift;
			my $captcha_type = shift;
			my $captcha_value;		
			dump_add(title => "captcha image", data => $captcha_data, type => $captcha_type);
			
			# Dump data in temporary file
			my ($fh, $captcha_file) = tempfile(SUFFIX => ".$captcha_type");
			print $fh $captcha_data;
			close($fh);
			
			# OCR
			if ($config->get("ocr") && $ocrcounter++ < 5) {
				# Preprocess
				if ($plugin->can("ocr_preprocess")) {
					$plugin->ocr_preprocess($captcha_file);
				}
				
				# Convert to tiff format
				my $captcha_file_ocr = $captcha_file;
				if ($captcha_type ne "tif") {	# FIXME: can't "tiff" get passed?
					my (undef, $captcha_converted) = tempfile(SUFFIX => ".tif");
					my $extra = "-alpha off -compress none";	# Tesseract is picky
					debug("converting captcha from $captcha_type:$captcha_file to tif:$captcha_converted");
					`convert $extra $captcha_type:$captcha_file tif:$captcha_converted`;
					if ($?) {
						error("could not convert captcha from given format '$captcha_type' to needed format 'tif', bailing out");
						goto USER;
					}
					$captcha_file_ocr = $captcha_converted;
				}
				
				# Apply OCR
				$captcha_value = `tesseract $captcha_file_ocr /tmp/slimrat-captcha > /dev/null 2>&1; cat /tmp/slimrat-captcha.txt; rm /tmp/slimrat-captcha.txt`;
				if ($?) {
					error("OCR failed");
					goto USER;
				}
				$captcha_value =~ s/\s+//g;
				debug("captcha read by OCR: '$captcha_value'");
				
				# Postprocess
				if ($plugin->can("ocr_postprocess")) {
					$captcha_value = $plugin->ocr_postprocess($captcha_value);
					debug("captcha after post-processing: '$captcha_value'");
				}
			}
			
			# User
			USER:
			$captcha_value = &$captcha_userreader($captcha_file) unless $captcha_value;
			
			die("no captcha entered") unless $captcha_value;
			debug("final captcha value: $captcha_value");
			return $captcha_value;
		},
		
		# Message processor
		# TODO: global message processor, also available in download_init|check|prepare?
		sub {
			# TODO: save per-thread/per-download messages internally
			info("Plugin message: ", @_);
		},
		
		# Custom headers
		\@headers
	);
	
	# Decrease all counters etc.
	$downloaders--;
	delete($rate_surplus{thread_id()});
	&$progress();
	
	# Check result ($response is a response object, should be successfull and not contain the custom X-Died header)
	# Any errors get sent to the upper eval{} clause
	if (! $response) {
		die("plugin did not return HTTP::Response object");
	} elsif (! $response->is_success) {
		die($response->status_line);
	} elsif ($response->header("X-Died")) {
		die($response->header("X-Died"));
	} else {			
		# Decode any content-encoding
		if ($encoding) {
			for my $ce (reverse split(/\s*,\s*/, lc($encoding))) {
				next unless $ce;
				next if $ce eq "identity";
				if ($ce =~ m/^(gzip|x-gzip|bzip2|deflate)/) {
					debug("uncompressing standard encodings");
					anyuncompress $filepath => "$filepath.temp", AutoClose => 1, BinModeOut => 1
						or die("could not decompress $ce, $AnyUncompressError");
					rename("$filepath.temp", $filepath);
				}
			}
		}
	}
}



#
# Other
#

# Quit all packages
sub quit {
	# Exit message
	info("exiting");
	
	# Quit all packages
	Queue::quit();
	Semaphore::quit();
	Proxy::quit();
	Log::quit();		# pre-last because it writes the dump
	Configuration::quit();	# last as used by everything
	
	# Gently quit running and/or exited threads
	debug("killing threads");
	if ($THRCOMP) {
		foreach (threads->list()) {
			$_->kill('INT')->join();
		}
	} else {
		no strict "subs";
		$_->join() foreach (threads->list(threads::joinable));
		$_->kill('INT')->join() foreach (threads->list(threads::running));
	}		

	# Exit with correct return value
	my $return = shift;
	$return = 255 if ($return !~ /^\d+$/);
	exit($return);
}

1;

