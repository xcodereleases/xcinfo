//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore
import Rainbow

extension XCInfo {
    struct Installed: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Show installed Xcode versions",
            discussion: "Show all installed versions of Xcode and their location on this computer."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @OptionGroup
        var listOptions: ListOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let core = Core(environment: .live(isVerboseLoggingEnabled: globals.isVerbose))
            try await core.installedXcodes(shouldUpdate: listOptions.updateList)
        }
    }
}
