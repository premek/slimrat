# slimrat - ReCaptcha extractor
#
# Copyright (c) 2011 Přemek Vyhnal
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
#    Přemek <premysl.vyhnal at gmail>
#

package ReCaptcha;

=head1 NAME

ReCaptcha - Helper class for extracting recaptcha images

=head1 SYNOPSIS

    use Recaptcha;

	if ($self->{MECH}->content() =~ m#challenge\?k=(.*?)"#) {
		my $recaptcha = ReCaptcha->new($self->{MECH}, $captcha_processor, $1);
		$recaptcha->submit();
		return 1;
	}
=cut

use WWW::Mechanize;

use Log;

# Write nicely
use strict;
use warnings;


=head1 METHODS

=head2 new($Mechanize_object, $catpcha_solver_function, $recaptcha_key)

Solves this captcha, extracts image, call solver funtion, logs everything.
Saves resulting captcha value and challenge ID.
=cut
sub new {
	my $self  = {};
	$self->{MECH} = $_[1];
	bless($self);	

	my $captcha_processor = $_[2];
	my $k = $_[3];


	my $captchascript = $self->{MECH}->get("http://api.recaptcha.net/challenge?k=$k")->decoded_content;
	dump_add(data => $self->{MECH}->content());

	($self->{CHALLENGE}, my $server) = $captchascript =~ m#challenge\s*:\s*'(.*?)'.*server\s*:\s*'(.*?)'#s;
	my $captcha_url = $server . 'image?c=' . $self->{CHALLENGE};

	debug("captcha url is ", $captcha_url);
	my $img_data = $self->{MECH}->get($captcha_url)->decoded_content;

	$self->{MECH}->back();
	$self->{MECH}->back();

	$self->{VALUE} = &$captcha_processor($img_data, "jpeg", 0);

	return $self;
}

=head2 submit()

Submits the form with fields recaptcha_response_field and recaptcha_challenge_field.
If another submit method is needed, use get_value and get_challenge functions to get 
values and make your own submit.
=cut
sub submit {
	my $self = shift;

	# Submit captcha form
	$self->{MECH}->submit_form( with_fields => {
			'recaptcha_response_field' => $self->{VALUE},
			'recaptcha_challenge_field' => $self->{CHALLENGE} });
	dump_add(data => $self->{MECH}->content());

}


=head2 get_value()

Returns the readed captha value.
=cut

sub get_value {
	return (shift->{VALUE});
}

=head2 get_challenge()

Returns challenge number needed to submit the captcha.

=cut

sub get_challenge {
	return (shift->{CHALLENGE});
}


=head1 AUTHOR

Premek Vyhnal <premysl.vyhnal gmail com>

=cut



1;
