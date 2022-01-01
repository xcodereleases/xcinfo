//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Download: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Downloads an Xcode version",
            discussion: "Downloads a specific version of Xcode."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Argument(
            help: "A version number of an Xcode version or `latest`.",
            transform: XcodeVersion.init
        )
        var xcodeVersion: XcodeVersion

        @Flag(inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool = true

        @Flag(
            name: [.customLong("sleep")],
            inversion: .prefixedNo,
            help: "Let the system sleep during execution."
        )
        var disableSleep: Bool = false

        @Option(
                help: "Number of connections to use to download."
        )
        var concurrent: Int = 5

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.download(
                releaseName: xcodeVersion.asString(),
                updateVersionList: updateList,
                disableSleep: disableSleep,
                concurrent: concurrent
            )
        }
    }
}
