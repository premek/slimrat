# Introduction #

This page is meant to be a guide on plugin development. It describes which routines should be implemented, what their function signature is, and how they might be implemented.

This guide is based upon Slimrat 1.0-beta, as of 2009-09-26 the **development version**. For information on earlier versions, have a look at existing plugins.



# Implementation #

Slimrat uses plugins to fetch data from a remote resource. The resource location is specified by a textual string, the Uniform Resource Locator (URL). URLs can point to several types of locations (a webserver like Rapidshare, some FTP server, a MMS multimedia server, ...), and a plugin has to be available to pass Slimrat the resource's data.

Every plugin has to be implemented in an object-oriented matter, which makes reuse of resources possible. Example: if the get\_size as well as the get\_filename function require the contents of an identical page, this page could be fetched once and saved for further use.

## Essential stuff ##

In order to function correctly, every plugin needs to do some very essential stuff:
  * provide licensing information,
  * set the build number,
  * configure a unique package name,
  * extend the Plugin base class (which provides some essential functionality),
  * include slimrat-specific packages (at least: Log and Configuration),
  * include other needed packages (at least: WWW::Mechanize).

This is how the plugin should look like after adding those items:
```
# slimrat - Some plugin you wrote
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
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#
# Plugin details:
##   BUILD 1
#

#
# Configuration
#

# Package name
package YourPackageName;

# Extend Plugin
@ISA = qw(Plugin);

# Packages
use WWW::Mechanize;

# Custom packages
use Log;
use Configuration;

# Write nicely
use strict;
use warnings;
```

When using exotic features of WWW::Mechanize, you might need to specify a minimum version (e.g. form\_name requires at least WWW::Mechanize 1.52). You can find that information at the relevant CPAN pages and version history.

Extending Plugin currently gives access to three extra methods:
  * "sub code", which returns the HTTP code of the last request (shouldn't be necessary in plugin code)
  * "sub fetch", which auto-magically fetches a given URL, dies upon failure, and submits the page to the dump handler. If no URL specified, the internal variable URL is used.
  * "sub reload", which reloads the current page and does all tasks mentioned in "sub fetch" above.

## Register ##

For Slimrat to know which plugin to use to process a given URL, each plugin has to register itself using a static function. This is done by a regular expression, using which every given URL is attempted to be matched with.

The following example code makes the plugin register itself to any URL containing rapidshare.com, eventually prefixed by a protocol specification (e.g. "http://") and an optional tag which here specifies the download server ("dl1.rapidshare.com", "dl2.rapidshare.com").
```
Plugin::register("^([^:/]+://)?([^.]+\.)?rapidshare.com");
```

## Resource handling ##

Slimrat needs to know how many concurrent downloads can be handled. You don't need to worry about any resource handling (this is done by extending the Plugin base class), but you do need to provide the amount of possible downloads. This is done with the static "provide" method:
```
Plugin::provide(1);
```
Any value > 0 indicates the maximal amount of concurrent downloads. Specifying -1 means that an infinite number of downloads can be processed concurrently.

## Constructor ##

The constructor has to create the initial object, and initialise any needed objects in order to get the data later on. An example of the most basic constructor is displayed below:
```
sub new {
	my $self  = {};
	$self->{CONF} = $_[1];
	$self->{URL} = $_[2];
	$self->{MECH} = $_[3];
	bless($self);
	
	$self->{PRIMARY} = $self->fetch();
	
	return $self;
}
```
As you see, the constructor is passed three arguments (actually four, but the first one is the class name, specific to the way how Perl implements OO):
  * a configuration object, which contains any plugin-specific settings,
  * the URL to download, which has been positively matched with the regex from above,
  * and a WWW::Mechanize instance, which can be used to click through forms and process sites.

You are advised to use the variable names mentioned in this example constructor (CONF, URL, MECH). Though not actually required for general use, you NEED to use this names when you want to use the methods provided by the Plugin base class (fetch and reload).

A truly optional variable is the PRIMARY one, which (as mentioned somewhere before) can be re-used in the "filename" and "check" subroutines. Not in the "get\_data" routine though, but that is explained later on.

When the plugin uses specific configuration values, a default value should be specified, or warnings will emitted. In order to do so, the relevant part of the constructor would look like:
```
	my $self = {};
	$self->{CONF} = $_[1];
	$self->{URL} = $_[2];
	$self->{MECH} = $_[3];
	bless($self);
	$self->{CONF}->set_default("foo", "bar");
```
If you want to use configuration values later on, you do as following:
```
	$self->{CONF}->get("foo")
```

Mind the location of the "bless" call though: it has to be called **before** any possibly erroneous instruction (e.g. a "die(...) if" instruction). If you do not respect this, the resource handling will get messed up as a failure to construct will not result in the destructor getting called (which, as you guessed, restores the allocated resources).

## Plugin name ##

This function returns the name of the plugin. This can be descriptive (e.g. "MMS-stream over UDP") and does not have to be unique. This contrary to the package name, which has to be an unique identifier used internally to register the plugins ("Plugin::get\_package($)").
```
sub get_name {
	return "Youtube";
}
```

## Filename ##

This method is used to determine the filename of the resulting (local) file. Popular HTTP download sites display the filename at the initial page, which would lead to code as:
```
sub get_filename {
	my $self = shift;

	return $1 if ($self->{PRIMARY}->decoded_content =~ m/Filename: <b>(.+?)<\/b>/);
}
```
This code will automatically return "undef" if the filename was not found.

## Filesize ##

This method returns the filesize in bytes. Returns 0 if unknown.

Function Toolbox::readable2bytes() can help with parsing values like '105 KB'.

```
sub get_filesize {
	my $self = shift;

	return readable2bytes($1) if ($self->{PRIMARY}->decoded_content =~ m/Filesize: <b>(.+?)<\/b>/);
}
```
Return values analogue to the get\_filename method. The "readable2bytes" call is used to convert a string indicating the filesize to an amount of bytes.

## Check ##

This method should check if the passed URL is up and alive. It differentiates the failure return value however:
  * return -1, when the link is DEAD (the download site reported so)
  * return 0, when the plugin doesn't really know if the URL is dead (404, or unknown error)
  * return 1, link is up and alive, and can be downloaded.
```
sub check {
	my $self = shift;
	
	$_ = $self->{PRIMARY}->decoded_content;
	return -1 if(m/The download doesnt exist/);
	return 1  if(m/Download Now !/);
	return 0;
}
```

## Get data ##

This is the main method of any plugin, and should download the data and reroute it to the first parameter of the get\_data method: a data processor routine.
The download routine is passed some other function references too, which can be used to process captcha's, or pass status messages. Finally, an object containing custom headers is passed too, which you should use in your final download request.

Generally, plugins process pages in a sequential way. This means the get\_data loads the initial page, after which the current page is matched against several actions (e.g. look for a captcha form, detect a wait timer, extract the final download url). If an action requires a reload or new fetch, this will update the current page, providing the newest information to following action checks.
An example:
# Load the initial page
# Have a look for the "Free" button
# Wait some seconds if a wait timer is present
# Generate the final download request

However, in most cases the order of actions can break out of that sequentiality. Have look at the previous example, and imagine the download site returns an "No free slots available" error. This error could occur after step 2 as well as step 3. When processing the page purely sequential using 'get\_data', this would mean adding a check for that error twice, or even more.
The solution to this, not astonishingly, is to wrap all the checks in a 'while 1' loop. In order to avoid code duplication in doing so, slimrat does the job for you. If you decide not to implement 'get\_data', but 'get\_data\_loop', the 'get\_data' function from the Plugin parent class is used. That function does some things for you:
**Reload the initial page** Call the 'get\_data\_loop' routine
**Analyse the return value:****If it's a HTTP::Response, return it to the upper class****If it's 'true', just call the 'get\_data\_loop' once more
Practically, this will mean you'll implement the 'get\_data\_loop' method, and fill it with checks and appropriate actions.** If you detect an error, just die(...).
**If you detect a situation after which all checks needs to be revisited, reload the page and return 1.** If sequentiality is ensured, just undertake an action and do not return (but continue the flow of checks).
**If the final download request is generated, just return it.**

This might sound complicated, but have a look at a clean plugin (e.g. the HotFile one), and you'll understand the flow. Just avoid looping in your plugin, if you need to loop use the existing framework of 'get\_data' & 'get\_data\_loop'. If it fails somewhere, just die, the caller will take care of retry handling.

### Method signature ###

This is the method description for 'get\_data' as well as 'get\_data\_loop':
```
sub get_data_loop {
	my $self = shift;
	my $data_processor = shift;
	my $captcha_processor = shift;
	my $message_processor = shift;
	my $headers = shift;
```

### Initial page ###

If you implement the 'get\_data\_loop' method, the initial page will get reloaded automatically. If you implement 'get\_data' yourself, you'll most likely need to reload the initial page. This because the 'get\_data' method **must** support getting called multiple times (in case of some error), if you don't reload the page it might be stuck at an error page from the previous 'get\_data' call.

E.g., this should be at the top of 'get\_data' if you implement it yourself:
```
# Fetch primary page
$self->reload();
```
This'll reload $self->{URL} and put the contents in the current page of $self->{MECH}


### Status messages ###

Your plugin should not use the Log package directly, which only serves as auxiliary library to provide command-line output. As (later on) the download engine will be interface independant, we don't want the plugins to output directly to the command line, but save its messages internally so each interface can request and display then appropriately.
Instead, use the $message\_processor function pointer:
```
&$message_processor("no download slots available, waiting 2 minutes");
wait(2*60);
```

### Actions ###

After the initial page is loaded, you will need to detect and respond to certain actions. An example of such an action might be to click a specific button (e.g. Rapidshare's FREE button):
```
# Click the "Free" button
if ($self->{MECH}->form_id("ff")) {
	my $res = $self->{MECH}->submit_form();
	die("secondary page error, ", $res->status_line) unless ($res->is_success);
	dump_add(data => $self->{MECH}->content());
	return 1;
}
```
As the Plugin base class does not provide any functionality to click forms, you here need to check and provide the dump manually -- stuff which normally is done auto-magically by the fetch/reload functions provided by the Plugin base class. NOTE: this might change though.
After we clicked to the next page, we return 1 to restart the loop. As this is the first action in the method, the return 1 may have been omitted, but we do it for the sake of consistency.

Another action might be respecting a wait timer:
```
# Wait timer
if ($self->{MECH}->content() =~ m/time = (\d+);/i) {
	wait($1, 1);
	$self->reload();
	return 1;	
}
```
The second argument to the wait call specifies if the wait is optional or not (a global configuration value then can be used to skip all optional waits).

Other actions result in the final download request. I'll document some cases in here:

#### Manual URL extraction ####

This is the case when the download URL is provided by not-executed code (e.g. Javascript).

```
if ($self->{MECH}->content() =~ m#var link_enc=new Array\('((.',')*.)'\);#) {
	my $download = $1;
	$download = join("", split("','", $download));
	
	return $self->{MECH}->request(HTTP::Request->new(GET => $download, $headers), $data_processor);
}
```

#### URL as <a href> in HTML ####

This is an easy one, just extract the URL based on some tags (which might be an regular expression matching the URL, or text within the <a> tags, ...). See WWW::Mechanize's documentation.<br>
<br>
<pre><code>if ($self-&gt;{MECH}-&gt;content() =~ m/\"downloadLink\"/) {<br>
	my $link = $self-&gt;{MECH}-&gt;find_link(url_regex =&gt; qr/\/dl\//) || die("could not find download link");<br>
	return $self-&gt;{MECH}-&gt;request(HTTP::Request-&gt;new(GET =&gt; $link-&gt;url, $headers), $data_processor);<br>
}<br>
</code></pre>

<h4>Redirect after filling in captcha</h4>

Another interesting case, in which you need to fill in a captcha, after which the redirected page contains the data.<br>
<br>
<pre><code>if (my $captcha = $self-&gt;{MECH}-&gt;find_image(url_regex =&gt; qr/kaptchacluster/i)) {<br>
	my $captcha_data = $self-&gt;{MECH}-&gt;get($captcha-&gt;url_abs())-&gt;content();<br>
	$self-&gt;{MECH}-&gt;back();<br>
	<br>
	# Process captcha<br>
	my $captcha_code = &amp;$captcha_reader($captcha_data, "jpeg");<br>
	<br>
	# Submit captcha form (TODO: a way to check if the captcha is correct, an is_html on the response?)<br>
	$self-&gt;{MECH}-&gt;form_with_fields("captcha");<br>
	$self-&gt;{MECH}-&gt;set_fields("captcha" =&gt; $captcha_code);<br>
	my $request = $self-&gt;{MECH}-&gt;{form}-&gt;make_request;<br>
	$request-&gt;header($headers);<br>
	return $self-&gt;{MECH}-&gt;request($request, $data_processor);<br>
}<br>
</code></pre>

Sometimes, the redirected page might need to be parsed as well. In here, this is not the case (EasyShare), with the disadvantage that (currently) it cannot be checked if the captcha value is actually correct.<br>
<br>
<h4>Form leads to download</h4>

In other cases, submitting a form will provide you with the download data.<br>
<br>
<pre><code>if (my $form = $self-&gt;{MECH}-&gt;form_name("downloadform")) {<br>
	my $request = $form-&gt;make_request;<br>
	$request-&gt;header($headers);<br>
	return $self-&gt;{MECH}-&gt;request($request, $data_processor);<br>
}<br>
</code></pre>

<h1>Notes</h1>

<h2>Error reporting</h2>

When an error occurs, just die. Again, the caller will take care of retry handling, you should not implement any loops to handle errors.