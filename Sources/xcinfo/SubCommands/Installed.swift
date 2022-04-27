//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Rainbow
import xcinfoCore

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
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
                try await core.installedXcodes(shouldUpdate: listOptions.updateList)
            } catch {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}
