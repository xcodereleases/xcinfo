//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Install: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Install an Xcode version",
            discussion: "Install a specific version of Xcode."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Argument(
            help: "A version number of an Xcode version or `latest`.",
            transform: XcodeVersion.init
        )
        var xcodeVersion: XcodeVersion

        @Flag(default: true, inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool

        @Flag(
            name: [.customLong("sleep")],
            default: false,
            inversion: .prefixedNo,
            help: "Let the system sleep during execution."
        )
        var disableSleep: Bool

        @Flag(
            name: [.customLong("no-symlink")],
            help: "Skip creating a symbolic link to `/Applications/Xcode.app`."
        )
        var skipSymlinkCreation: Bool

        @Flag(
            name: [.customLong("no-xcode-select")],
            help: "Skip selecting the new Xcode version as the current Command Line Tools."
        )
        var skipXcodeSelection: Bool

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.install(releaseName: xcodeVersion.asString(),
                         updateVersionList: updateList,
                         disableSleep: disableSleep,
                         skipSymlinkCreation: skipSymlinkCreation,
                         skipXcodeSelection: true)
        }
    }
}
