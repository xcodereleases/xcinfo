//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Rainbow
import xcinfoCore

extension XCInfo {
    struct Info: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Xcode version info",
            discussion: "Display information like SDK, release note link, etc of an Xcode version."
        )

        @OptionGroup()
        var versionOption: VersionOptions

        @OptionGroup
        var listOptions: ListOptions

        @OptionGroup()
        var globals: DefaultOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
                try await core.info(version: versionOption.xcodeVersion, shouldUpdate: listOptions.updateList)
            } catch {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}
