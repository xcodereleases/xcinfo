//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Installed: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Show installed Xcode versions",
            discussion: "Show all installed versions of Xcode and their location on this computer."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Flag(default: true, inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.installedXcodes(updateList: updateList)
        }
    }
}
