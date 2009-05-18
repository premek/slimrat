# SlimRat 
# Tim Besard <tim.besard gmail com> 2009 
# public domain

#
# Configuration
#

package Queue;

# Write nicely
use strict;
use warnings;

#
# Routines
#

# Constructor
sub new {
	my $self = {
		_file		=>	undef,
		_manual		=>	[],
	};
	bless $self, 'Queue';
	return $self;
}

# Add a single url
sub add {
	my ($self, $url) = @_;

	push(@{$self->{_manual}}, $url);
}

# Set the file
sub file {
	my ($self, $file) = @_;
	
	$self->{_file} = $file;
}

# Get an URL
sub get {
	my ($self) = @_;
	
	# Check if we got manually added urls queue'd up
	if (scalar(@{$self->{_manual}}) > 0) {
		return shift(@{$self->{_manual}});
	}
	
	# Read the file and extract an URL
	elsif (defined($self->{_file})) {
		open(FILE, $self->{_file});
		while (<FILE>) {
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			if ($_ =~ m/^\s*(\S+)\s*/) {
				close(FILE);
				return $1;
			}
		}
		close(FILE);
	}
	
	# All url's processed
	$self->{_empty} = 1;
	return;
}

# Get everything (all URL at once)
sub dump {
	my ($self) = @_;
	
	my @output;
		
	# Manually added URL's
	if (scalar(@{$self->{_manual}}) > 0) {
		foreach (@{$self->{_manual}}) {
			push(@output, $_);
		}
	}
	
	# File contents
	if (defined($self->{file})) {
		open(FILE, $self->{_file});
		while (<FILE>) {
			next if /^#/;		# Skip comments
			next if /^\s*$/;	# Skip blank lines
			if ($_ =~ m/^\s*(\S+)\s*/) {
				push(@output, $1);
			}
		}
		close(FILE);
	}
	
	# Return reference
	return \@output;
}


# Change the status of an URL (and update the file)
sub update {
	my ($self, $url, $status) = @_;
	
	# Only update if we got a file
	if (defined($self->{_file})) {
		open (FILE, $self->{_file});
		open (FILE2, ">".$self->{_file}.".temp");
		while(<FILE>) {
			if (!/^#/ && /$url/) {
				print FILE2 "# ".$status.": ";
			}
			print FILE2 $_;
		}
		close FILE;
		close FILE2;
		unlink $self->{_file};
		rename $self->{_file}.".temp", $self->{_file};
	}	
}


1;
