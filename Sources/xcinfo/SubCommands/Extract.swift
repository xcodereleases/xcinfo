//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore
import Rainbow
import Foundation

extension XCInfo {
    struct Extract: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Extract an Xcode XIB"
        )

        @Argument
        var source: URL

        @OptionGroup
        var extractionOptions: ExtractionOptions

        @OptionGroup()
        var globals: DefaultOptions

        func run() async throws {
            Rainbow.enabled = globals.useANSI
            let environment = Environment.live(isVerboseLoggingEnabled: globals.isVerbose)
            let core = Core(environment: environment)
            do {
                try await core.extractXIP(source: source, options: extractionOptions.options)
            } catch let error as CoreError {
                environment.logger.error(error.localizedDescription)
                throw ExitCode.failure
            }
        }
    }
}

extension ExtractionOptions {
    var options: Core.ExtractionOptions {
        .init(destination: installationDirectory, useExperimentalUnxip: useExperimentalUnxip)
    }
}
