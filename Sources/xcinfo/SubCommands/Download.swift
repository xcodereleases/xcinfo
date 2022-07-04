//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Rainbow
import xcinfoCore

extension XCInfo {
    struct Download: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Downloads an Xcode version",
            discussion: "Downloads a specific version of Xcode."
        )

        @OptionGroup
        var versionOptions: VersionOptions

        @OptionGroup
        var downloadOptions: DownloadOptions

        @OptionGroup()
        var globals: DefaultOptions

        @OptionGroup
        var listOptions: ListOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
                try await core.download(
                    version: versionOptions.xcodeVersion,
                    options: downloadOptions.options,
                    updateVersionList: listOptions.updateList
                )
            } catch let error as CoreError {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}

extension DownloadOptions {
    var options: Core.DownloadOptions {
        .init(destination: downloadDirectory,
							buildRelease: .init(buildNo: buildReleaseOptions.build,
																	releaseType: buildReleaseOptions.release),
							disableSleep: disableSleep)
    }
}
