//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Installed: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Show installed Xcode versions",
            discussion: "Show all installed versions of Xcode and their location on this computer."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Flag(inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool = true

        func run() async throws {
            let core = Core(environment: .live)
            try await core.installedXcodes(shouldUpdate: updateList)
        }
    }
}
