//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Rainbow
import xcinfoCore

extension XCInfo {
    struct Cleanup: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Remove stored credentials",
            discussion: "Remove stored Apple ID credentials and session authentification items from the macOS keychain."
        )

        @OptionGroup()
        var globals: DefaultOptions

        func run() throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            core.cleanup()
        }
    }
}
