# xcinfo

With `xcinfo` you can access all information available at xcodereleases.com and install available Xcode versions from Apple's Developer Portal. It also finds and lists installed Xcode applications on hard drive and you can remove them safely.

![Screenhot of the install progress](https://github.com/xcodereleases/xcinfo/blob/master/Assets/install.png?raw=true)

```
USAGE: xcinfo <subcommand>

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  info                    Xcode version info
  list                    List all available Xcode versions
  install                 Install an Xcode version
  installed               Show installed Xcode versions
  uninstall               Uninstall an Xcode version
  cleanup                 Remove stored credentials
```

## Requirements
- macOS 10.15 (Catalina)
- Swift 5.1

## Installation

### Manually
```
$ git clone https://github.com/xcodereleases/xcinfo.git
$ cd xcinfo
$ make
$ sudo make install
```

### Make
- Build a universal (`arm64` and `x86_64`) xcinfo: `make`
- Install xcinfo (default to `/usr/local/bin`): `sudo make install` or to other local: `sudo make install prefix=/opt/local`
- Clean build caches: `make clean`
- Cleanup all caches: `make cleanup`

### Mint
```
$ mint install xcodereleases/xcinfo
```

### homebrew
```
$ brew install xcinfo
```

## Usage

### info (default)
- show detailed information about a version of Xcode

### list
- list all available Xcode versions ever released by Apple

### install
- download and install a version of Xcode

### installed
- list Xcode versions installed in /Applications

### uninstall
- removes an installed version of Xcode from /Applications

### cleanup
- if something goes wrong this removes all entries stored in the keychain, all cookies, and user defaults

## CI
- no-ansi flag to suppress colored output
- verbose flag

## Screenshots

![Show info for a specific Xcode version](https://github.com/xcodereleases/xcinfo/blob/master/Assets/inf.png?raw=true)

![Installed and available Xcode versions](https://github.com/xcodereleases/xcinfo/blob/master/Assets/list.png?raw=true)

## TODO
- sudo support without storing user password in memory
- man page
- tests
- include default data (when github is offline)

## Changelog

### Version 0.6.0
Adds:
- resuming of aborted downloads (Thanks @chippo)

### Version 0.5.1
Fixes:
-  version string 

### Version 0.5.0

Initial public release
