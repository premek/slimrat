# slimrat - MediaFire plugin
#
# Copyright (c) 2008 Tomasz Gągor
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
#    Tomasz Gągor <timor o2 pl>
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#
# Configuration
#

# Package name
package MediaFire;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;

# Custom packages
use Log;
use Toolbox;
use Configuration;

# Write nicely
use strict;
use warnings;


#
# Routines
#

# Constructor
sub new {
	my $self  = {};
	$self->{CONF} = $_[1];
	$self->{URL} = $_[2];
	$self->{MECH} = $_[3];
	bless($self);
	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}

# Plugin name
sub get_name {
	return "MediaFire";
}

# Filename
sub get_filename {
	my $self = shift;
	
	return $1 if ($self->{PRIMARY}->decoded_content =~ m/<input type="hidden" id="sharedtabsfileinfo1-fn" value="(.*?)">/);
}

# Filesize
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/<input type="hidden" id="sharedtabsfileinfo1-fs" value="(.*?)">/);
}

# Check if the link is alive
sub check {
	my $self = shift;
	
	return 1 if ($self->{PRIMARY}->decoded_content =~ m/  cu\('(\w+)','(\w+)','(\w+)'\);  if\(fu/);
	return -1 if ($self->{PRIMARY}->decoded_content =~ m/value="upload"/);
	return -1 if ($self->{MECH}->uri() =~ m/error.php/);
	return 0;
}

# Download data
sub get_data_loop  {
	# Input data
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;

	
	$_ = $self->{MECH}->content()."\n";

	# store divs from first page
	my %divs;
	while(m/<div class=".*?" style=".*?" id="(.{32})" name=".*?">Preparing download/g){
		$divs{$1} = 1;
	}

	my ($qk, $pk1, $r);
	($qk) = m/qk=(.+?)'/;
	($r) = m/pKr='(.+?)'/;

	my $todecypher;
	while(m/=(unescape\(.+?;)eval\(/g){
		$todecypher = $1; # last unescape
	}

	($pk1) = decypher($todecypher) =~ m/','(.+?)'/;

	unless($qk and $pk1 and $r){
		die("cannot extract secondary page");
	}
	
	# Get the secondary page
	my $res = $self->fetch("http://www.mediafire.com/dynamic/download.php?qk=$qk&pk1=$pk1&r=$r");

print "2nd page\n\n\n";

	$_ = $res->decoded_content."\n";

#	my $vars = (split /eval/)[0];
	my $vars = decypher($_); # the first piece of...
	my %variables;
	while ($vars =~ m/([^= ]+)\s*=\s*'([^']*)';/g) {
		$variables{$1} = $2;
	}

#		print "$vars\n\n----\n";
use Data::Dumper;
#print Dumper(%divs);
#print Dumper(%variables);
	dump_add(data => Dumper(\%variables));
	dump_add(data => Dumper(\%divs));


#

# 5. from end

#	m/ (.+?='';.+?=unescape\('if.+?\^\d+\)\);eval\(.+?\))/;
#
#		$todecypher = $1; 
#
#	print decypher($todecypher) ;
#	print "___";
#


	my @codes = split /eval\(/;
	dump_add(data => Dumper(\@codes));
	m/unescape/ and decypher($_) foreach(@codes);


#		while(m/=(unescape\(.+?);eval\(/gs){
#		print "\n\nAAAAAAAAAAAAAAA-------\n\n";
#
#			decypher($1);
#		}

		print "\n\n-------\n\n";

#	while(m/parent\.document\.getElementById\('(.{32})'\)\).*?href=\\"(.+?\/)" \+(.+?)\+ "(.+?)\\"/gs){
#		print "$1\n";
#		if($divs{$1}){
#			my $url = $2.$variables{$3}.$4;
#			print $url."\n";
#`wget $url`;
#		}
#	}


	return;


		# Download the data
#	return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);

	
}




# decodes this:
#w443v957m='';tgsjbb4=unescape('%shitshit');s59f4x536oa=4871;for(i=0;i<s59f4x536oa;i++)w443v957m=w443v957m+(String.fromCharCode(tgsjbb4.charCodeAt(i)^5^7));
sub decypher{
	print "\n\n--\nDECY @_";
	$_ = shift;
	my %variables = shift || ();

#	eval("a17p4=\'\';zad=unescape(\'%7Df31g5fai%7Dl%2C%23kpin%7E%60q%7E4%7Dl%23%28%23e1%3D1202g2f5%3C5a63e%60%3C650%6054617gg300a%60%3Daba%605%3Db756b%3C142g63a45a3%3Cgb4a3750e1011b1124a3%3Ce730e2%6057b424%3Ca%23-\');vzs9uyh=125;for(i=0;i<vzs9uyh;i++)a17p4=a17p4+(String.fromCharCode(zad.charCodeAt(i)^4^5^5));eval(a17p4);");
	if(/^eval/){
		s/\\'/'/g;
		/eval\("(.*?)"\)/;
		return decypher($1);
	}



	(my $code) = m/unescape\('(.+?)'\)/;
	(my $xor) = m/charCodeAt\(i\)((?:\^\d+)+)/;
	my @xor = split /\^/,$xor;
	shift @xor;

	#print  ("cbl='".unescape($pk1)."'; rwa=''; zp62c=313;for(i=0;i<zp62c;i++)rwa=rwa+(String.fromCharCode(cbl.charCodeAt(i)$xor));");
	my $result = pack("C*", map(nxor($_,@xor), unpack("C*", unescape($code))));



	# if(ha38a!="044837637bb")
print "\n>>>> $result\n\n--\n";
 
	return "" if($result =~ /if\((.+?)!="(.+?)"/ and defined $variables{$1} and $variables{$1}==$2);

	return decypher ($result) if($result =~ /eval/);

	return $result;

}

sub nxor{
	# returns $n ^ $xor1 ^ xor2 ^ $xor3 ^ ...
	my($n, @xor) = @_;
	$n=$n^$_ foreach (@xor);
	return $n
}


# Copyright Koichi Taniguchi 
sub unescape {
    my $escaped = shift;
    $escaped =~ s/%u([0-9a-f]{4})/chr(hex($1))/eig;
    $escaped =~ s/%([0-9a-f]{2})/chr(hex($1))/eig;
    return $escaped;
}


# Amount of resources
Plugin::provide(1);

# Register the plugin
Plugin::register("^[^/]+//(?:www.)?mediafire.com");

1;
