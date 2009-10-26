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

# Version information
our $VERSION = '1.0';

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
	my $mech = WWW::Mechanize->new(autocheck => 0);
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
# Downloading
#

# Redirect download() call to the correct plugin
# Possible return values (quite analogue to the plugin's check() function):
#   1 = download successfully completed
#   0 = download failed, for unknown reason
#   -1 = download failed because URL is dead
#   -2 = plugin error
sub download {
	my ($mech, $link, $to, $progress, $captcha_user_read, $no_lock) = @_;
	$no_lock = 0 unless defined($no_lock);
	info("downloading '$link'");
	
	
	# CONSTRUCTION #
	CONSTRUCTION:
	my $plugin;
	
	# Load the retry counter
	my $counter = $config->get("retry_count");
	
	eval {
		# Configure DIE handler to provide stack traces (TODO: ditch eval and avoid code duplication)
		local $SIG{__DIE__} = sub {
			$_[0] =~ m/^(.+)\sat\s/;
			confess($1);
		};
		
		# Load plugin
		$plugin = Plugin->new($link, $mech, $no_lock);
		
		# Return -3 if the caller requested to manage insufficient resources hisself	
		if ($no_lock && $plugin == -1) {
			return -3;
		}
		
		# Get plugin name
		my $pluginname = $plugin->get_name();
	
		debug("instantiated a $pluginname downloader");
	};
	
	if ($@) {
		my $error_raw = $@;	# Because $@ gets overwritten after confess in error()
		my ($error) = $@ =~ m/^(.+)\sat/; 
		my $fatal = $error =~ s/^fatal: //i;
		error("download failed while constructing ($error)");	# TODO: this error prints a callstack as well
		callstack_confess($error_raw, 1);	# Strip the signal handler
		if (!$fatal && $counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto CONSTRUCTION;
		} elsif ($fatal) {
			info("error to severe to attempt another try, bailing out");
		}
		return -2;
	}
		
	# Return -3 if the caller requested to manage insufficient resources hisself
	# FIXME: yeah this sucks, I know
	if ($no_lock && $plugin == -1) {
		return -3;
	}
	
	
	# CHECK #
	CHECK:
	my $status;
	
	eval {
		# Configure DIE handler to provide stack traces (TODO: ditch eval and avoid code duplication)
		local $SIG{__DIE__} = sub {
			$_[0] =~ m/^(.+)\sat\s/;
			confess($1);
		};
		
		# Check the URL
		$status = $plugin->check();
	};
	
	if ($@) {
		my $error_raw = $@;	# Because $@ gets overwritten after confess in error()
		my ($error) = $@ =~ m/^(.+)\sat/; 
		my $fatal = $error =~ s/^fatal: //i;
		error("download failed while checking ($error)");	# TODO: this error prints a callstack as well
		callstack_confess($error_raw, 1);	# Strip the signal handler
		if (!$fatal && $counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto CHECK;
		} elsif ($fatal) {
			info("error to severe to attempt another try, bailing out");
		}
		return -2;
	}	

	warning("check failed (unknown reason)") if ($status == 0);	
	error("check failed (dead link)") if ($status < 0);
	return $status if ($status < 0);
	

	# PREPARATION #
	PREPARATION:
	my $filename;
	my $filepath;
	
	eval {
		# Configure DIE handler to provide stack traces (TODO: ditch eval and avoid code duplication)
		local $SIG{__DIE__} = sub {
			$_[0] =~ m/^(.+)\sat\s/;
			confess($1);
		};
		
		# Check if we can write to "to" directory
		return error("directory '$to' not writable") unless (-d $to && -w $to);
		
		# Get destination filename
		$filename = $plugin->get_filename();
		if (!$filename) {
			warning("could not deduce filename, falling back to default string");
			$filename = "SLIMRAT_DOWNLOADED_FILE";
		} elsif ($config->get("escape_filenames")) {
			$filename =~ s/([^a-zA-Z0-9_\.\-\+\~])/_/g; 
		}
		$filepath = "$to/$filename";
	};
	
	if ($@) {
		my $error_raw = $@;	# Because $@ gets overwritten after confess in error()
		my ($error) = $@ =~ m/^(.+)\sat/; 
		my $fatal = $error =~ s/^fatal: //i;
		error("download failed while preparing ($error)");	# TODO: this error prints a callstack as well
		callstack_confess($error_raw, 1);	# Strip the signal handler
		if (!$fatal && $counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto PREPARATION;
		} elsif ($fatal) {
			info("error to severe to attempt another try, bailing out");
		}
		return -2;
	}
	
	
	# DOWNLOAD #
	DOWNLOAD:
	my $size;
	my $time_start = time;
	my $time_chunk = time;
	my $size_downloaded = 0;
	my $size_chunk;
	my $speed = 0;
	
	# Check if file exists
	my @headers;
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
			push(@headers, Range => "bytes=" . (-s $filepath) . "-");
			$size_downloaded = -s $filepath;
		} else {
			fatal("unrecognised action upon redownload");
		}
	}
	info("file will be saved as '$filepath'");
	
	# Get data
	my $encoding;
	my $encoding_extra;
	my $flag = 0;
	my $ocrcounter = 0;
	$|++; # unbuffered output
	$downloaders++;
	my $response;
	eval {
		# Configure DIE handler to provide stack traces (TODO: ditch eval and avoid code duplication)
		local $SIG{__DIE__} = sub {
			$_[0] =~ m/^(.+)\sat\s/;
			confess($1);
		};
		
		# Get the data
		$response = $plugin->get_data(
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
						elsif ($res->code() == 200) {
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
				if ($config->contains("rate")) {
					my $speed_cur = $size_chunk / $dtime_chunk;
					my $speed_aim = $config->get("rate") * 1024 / $downloaders;
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
					# Weighted speed calculation
					if ($speed) {
						$speed /= 2;
						$speed += ($size_chunk / $dtime_chunk) / 2;
					} else {
						$speed = $size_chunk / $dtime_chunk;
					}
					
					# Calculate ETA
					my $eta = -1;
					$eta = ($size - $size_downloaded) / $speed if ($speed && $size);
					
					# Update progress
					&$progress($size_downloaded, $size, $speed, $eta);
					
					# Reset counters for next chunk
					$size_chunk = 0;
					$time_chunk = gettimeofday();
				}
			}, sub { # autoread captcha if configured, else let user read it
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
				$captcha_value = &$captcha_user_read($captcha_file) unless $captcha_value;
				
				die("no captcha entered") unless $captcha_value;
				debug("final captcha value: $captcha_value");
				return $captcha_value;
			},
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
	};
	
	if ($@) {
		my $error_raw = $@;	# Because $@ gets overwritten after confess in error()
		my ($error) = $@ =~ m/^(.+)\sat/; 
		my $fatal = $error =~ s/^fatal: //i;
		error("download failed ($error)");	# TODO: this error prints a callstack as well
		callstack_confess($error_raw, 1);	# Strip the signal handler
		if (!$fatal && $counter-- > 0) {
			info("retrying $counter more times");
			wait($config->get("retry_wait"));
			goto DOWNLOAD;
		} elsif ($fatal) {
			info("error to severe to attempt another try, bailing out");
		}
		return -2;
	}
	
	# Close file
	close(FILE);	

}

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

