# xcinfo

- provides access to data of xcodereleases.com via api
- downloads and installs specific Xcode versions
- finds and lists installed Xcode version on hard drive
- removes installed Xcode versions

## Installation

### Manually
- checkout
- run `swift build -c release`
- run `cp .build/release/xcinfo /usr/local/bin`

### homebrew
- tbd

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

## TODO
- `latest` argument for install subcommand (e.g. `xcinfo install latest`)
- man page
- tests
- include default data (when github is offline)
- homebrew support?
