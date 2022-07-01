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

        @Flag(
            inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool = true

        @Flag(
            name: [.customLong("sleep")],
            inversion: .prefixedNo,
            help: "Let the system sleep during execution."
        )
        var disableSleep: Bool = false

        @Flag(
            name: [.customLong("no-symlink")],
            help: "Skip creating a symbolic link to `/Applications/Xcode.app`."
        )
        var skipSymlinkCreation: Bool = false

        @Flag(
            name: [.customLong("no-xcode-select")],
            help: "Skip selecting the new Xcode version as the current Command Line Tools."
        )
        var skipXcodeSelection: Bool = false

        @Flag(
            name: [.customLong("xip-deletion")],
            inversion: .prefixedEnableDisable,
            help: "Configure whether the downloaded XIP should be deleted after extraction or not."
        )
        var shouldDeleteXIP: Bool = true

				@Option(name: .shortAndLong, help: "Build version to use (if provided).")
				var build: String?

				@Option(name: .shortAndLong, help: "Release name to use (if provided).")
				var release: String?

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.install(releaseName: xcodeVersion.asString(),
												 build: build,
												 release: release,
                         updateVersionList: updateList,
                         disableSleep: disableSleep,
                         skipSymlinkCreation: skipSymlinkCreation,
                         skipXcodeSelection: skipXcodeSelection,
												 shouldDeleteXIP: shouldDeleteXIP)
        }
    }
}
