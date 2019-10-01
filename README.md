# xcinfo


- provides access to data of xcodereleases.com via api
- downloads and installs specific Xcode versions
- finds and lists installed Xcode version on hard drive
- removes installed Xcode versions

## Installation

### Manually
- checkout
- run `swift build`
- run `cp .build/debug/xcinfo /usr/local/bin`

### homebrew
- tbd

## Subcommands

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

## CLI Integration

- no-ansi flag to suppress colored output
- verbose flag

## Screenshots

## TODO

- man page
- tests
- include default data (when github is offline)
- homebrew support?
