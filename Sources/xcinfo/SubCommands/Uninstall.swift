//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Rainbow
import xcinfoCore

extension XCInfo {
    struct Uninstall: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Uninstall an Xcode version",
            discussion: "Uninstall a specific version of Xcode."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Argument(
            help: "The version number of the Xcode to uninstall."
        )
        var xcodeVersion: String?

        @OptionGroup
        var listOptions: ListOptions

				@OptionGroup
				var buildReleaseOptions: BuildReleaseOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
							try await core.uninstall(xcodeVersion?.lowercased(),
																			 buildRelease: .init(buildNo: buildReleaseOptions.build,
																													 releaseType: buildReleaseOptions.release),
																			 updateVersionList: listOptions.updateList)
            } catch let error as CoreError {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}
