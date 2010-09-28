# slimrat - multi-platform GTK2-based clipboard manager
#
# Copyright (c) 2009 Torsten Schoenfeld
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
# The Standard Version specified to be licensed under the same
# conditions of Perl, which at the time of writing (2009/10/13)
# is the Artistic License version 1.0. In order to comply with
# this license (section 3, item a) all modifications are made
# freely available to the Copyright Holder.
#
# Authors:
#	Torsten Schoenfeld <kaffeetisch gmx de>
#

#
# Configuration
#

# Package name
package Clipboard;

# Packages
use Gtk2;

# Write nicely
use strict;
use warnings;

# Static clipboard reference
#   According to
#   <http://standards.freedesktop.org/clipboards-spec/clipboards-latest.txt>,
#   explicit cut/copy/paste commands should always use CLIPBOARD.
my $clipboard = Gtk2::Clipboard->get(Gtk2::Gdk::Atom->new('CLIPBOARD'));


#
# Static functionality
#

# Copy given text to the clipboard
sub copy {
	my ($self, $input) = @_;
	$clipboard->set_text($input);
}

# Cut given text to the clipboard, which in here equals to copying.
sub cut {
	goto &copy
}

# Paste (return) text from the clipboard.
sub paste {
	my ($self) = @_;
	return $clipboard->wait_for_text();
}

# Return
1;


#
# Documentation
#

=head1 NAME

Clipboard - Copy and paste with any OS

=head1 SYNOPSIS

	use Clipboard;
	print Clipboard->paste;
	Clipboard->copy('foo');

	# Clipboard->cut() is an alias for copy().  copy() is the preferred
	# method, because we're not really "cutting" anything.

=head1 DESCRIPTION

Who doesn't remember the first time they learned to copy and paste, and
generated an exponentially growing text document?   Yes, that's right,
clipboards are magical.

With Clipboard.pm, this magic is now trivial to access,
cross-platformly, from your Perl code.

=head1 STATUS

Seems to be working well for Linux.  Should also be working on OSX, *BSD, and
Windows.

=head1 AUTHOR

Torsten Schoenfeld <kaffeetisch gmx de>

=head1 LICENSE

Licensing details are prepended to the sourcefile.

=cut

