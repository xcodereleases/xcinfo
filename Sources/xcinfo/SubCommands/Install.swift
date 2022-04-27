//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Foundation
import Rainbow
import xcinfoCore

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
                        version: installationOptions.versionOptions.xcodeVersion,
                        xipFile: installationOptions.xipFile,
                        downloadOptions: installationOptions.downloadOptions.options,
                        extractionOptions: installationOptions.extractionOptions.options,
                        skipSymlinkCreation: installationOptions.skipSymlinkCreation,
                        skipXcodeSelection: installationOptions.skipXcodeSelection,
                        shouldPreserveXIP: installationOptions.shouldPreserveXIP
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
