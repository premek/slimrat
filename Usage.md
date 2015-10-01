# Slimrat usage #

This document is based upon Slimrat 0.9.5, for other versions, see the usage bundled with the script:
```
$ slimrat --help
```

Version 0.9.5 and above includes a more thorough help:
```
$ slimrat --man
```

## CLI and GUI clients ##

Both the CLI and the GUI client parse two configuration files:
  1. System-wide configuration file, located at _/etc/slimrat.conf_
  1. User-specific configuration file, located at _~/.slimrat/config_

The tarball includes a sample configuration file, which documents all supported options. Some are GUI specific, other aren't (documented in the sample configuration file as well).

It is also possible for the system admin to force certain options, by setting a configuration value and making it immutable after it:
```
log_file == /var/log/slimrat.log
```
Now every slimrat instance will always log there, and no user will be able to avoid this setting.
This might later on be very handy when combined with scheduling options.

## CLI client ##

The CLI client can takse parameters over the command-line, as well as through the previously mentioned configuration file. All options are complementary to the ones in the configuration file, which means you won't be able either to override a previously set immutable value. See _slimrat --man_ for an explanation of all options.

## GUI client ##

The GUI client can at the moment only be configured by editing the configuration file, or through the currently quite limited GUI functionality.

### GUI hotkeys ###
| Ctrl-V | Insert links from clipboard|
|:-------|:---------------------------|
| Insert | Add links dialog           |
| Ctrl-Enter | OK in "add links dialog"   |