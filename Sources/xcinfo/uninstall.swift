//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Uninstall: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Uninstall an Xcode version",
            discussion: "Uninstall a specific version of Xcode."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Argument(
            help: "A version number of an Xcode version."
        )
        var xcodeVersion: String?

        @Flag(inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool = false

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.uninstall(xcodeVersion?.lowercased(), updateVersionList: updateList)
        }
    }
}
