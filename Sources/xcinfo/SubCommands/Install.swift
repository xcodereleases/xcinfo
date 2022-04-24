//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore
import Rainbow
import Foundation

extension XCInfo {
    struct Install: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Install an Xcode version",
            discussion: "Install a specific version of Xcode."
        )

        @OptionGroup
        var installationOptions: InstallationOptions

        @OptionGroup
        var listOptions: ListOptions

        @OptionGroup()
        var globals: DefaultOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
                try await core.install(
                    options: .init(
                        downloadOptions: installationOptions.downloadOptions.options,
                        extractionOptions: installationOptions.extractionOptions.options,
                        skipSymlinkCreation: installationOptions.skipSymlinkCreation,
                        skipXcodeSelection: installationOptions.skipXcodeSelection,
                        shouldDeleteXIP: installationOptions.shouldDeleteXIP
                    ),
                    updateVersionList: listOptions.updateList
                )
            } catch let error as CoreError {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}
