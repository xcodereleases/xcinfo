//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension XCInfo {
    struct Info: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Xcode version info",
            discussion: "Display information like SDK, release note link, etc of an Xcode version."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Argument(
            help: "A version number of an Xcode version or `latest`.",
            transform: XcodeVersion.init
        )
        var xcodeVersion: XcodeVersion?

				@Option(name: .shortAndLong, help: "Build version to use (if provided).")
				var build: String?

				@Option(name: .shortAndLong, help: "Release name to use (if provided).")
				var release: String?

//        func validate() throws {
//            if case let .version(versionString) = xcodeVersion {
//                let normalizedVersion = versionString
//                    .lowercased()
//                    .replacingOccurrences(of: " ", with: ".")
//                    .replacingOccurrences(of: ".beta", with: "-beta")
//                do {
//                    _ = try Version(normalizedVersion)
//                } catch {
//                    throw ValidationError("Please provide either an Xcode version or `latest`.")
//                }
//            }
//        }

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.info(releaseName: xcodeVersion?.asString(), build: build, release: release)
        }
    }
}

//var infoCommand = Command(
//    usage: "info",
//    configuration: configuration,
//    run: execute
//)
//
//private func configuration(command: Command) {
//    command.shortMessage = "Xcode version info"
//    command.longMessage = "Display information like SDK, release note link, etc of an Xcode version."
//    command.example = #"xcinfo info 11\#nxcinfo info "11 Beta 5"\#nxcinfo info 11M382q"#
//}
//
//private func execute(flags: Flags, args: [String]) {
//    let isVerbose = flags.getBool(name: "verbose") == true
//    let useANSI = flags.getBool(name: "no-ansi") == false
//
//    guard args.count <= 1 else {
//        return print(installCommand.helpMessage)
//    }
//
//    let releaseName = args.first
//    let core = xcinfoCore(verbose: isVerbose, useANSI: useANSI)
//    core.info(releaseName: releaseName)
//}
