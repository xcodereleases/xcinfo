//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore
import Foundation

@main
struct XCInfo: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xcinfo",
        version: version,
        subcommands: [
//            Info.self,
            Install.self,
            List.self,
            Download.self,
            Installed.self,
            Extract.self,
//            Uninstall.self,
//            Cleanup.self,
        ]
    )
}

struct DefaultOptions: ParsableArguments {
    @Flag(
        name: [.customLong("verbose"), .customShort("v")],
        help: "Show more debugging information."
    )
    var isVerbose: Bool = false

    @Flag(name: .customLong("ansi"), inversion: .prefixedNo, help: "Show output with colors.")
    var useANSI: Bool = true
}

struct ListOptions: ParsableArguments {
    @Flag(
        inversion: .prefixedNo,
        help: "Update the list of known Xcode versions."
    )
    var updateList = true
}

struct DownloadOptions: ParsableArguments {
    @Argument(
        help: "A version number of an Xcode version or `latest`.",
        transform: XcodeVersion.init
    )
    var xcodeVersion: XcodeVersion

    @Option(
        name: [.long, .short],
        help: "The download destination folder."
    )
    var downloadDirectory: URL = URL(fileURLWithPath: "\(NSHomeDirectory())/Downloads").standardizedFileURL

    @Flag(
        name: [.customLong("sleep")],
        inversion: .prefixedNo,
        help: "Let the system sleep during execution."
    )
    var disableSleep: Bool = false
}

struct ExtractionOptions: ParsableArguments {
    @Option(
        name: [.long, .short],
        help: "The directory to install the code version in."
    )
    var installationDirectory: URL = URL(fileURLWithPath: "/Applications")

    @Flag(
        help: "Uses experimental (way faster) version of unxip."
    )
    var useExperimentalUnxip: Bool = false
}

struct InstallationOptions: ParsableArguments {
    @OptionGroup
    var downloadOptions: DownloadOptions

    @OptionGroup
    var extractionOptions: ExtractionOptions

    @Flag(
        name: [.customLong("no-symlink")],
        help: "Skip creating a symbolic link to `/Applications/Xcode.app`."
    )
    var skipSymlinkCreation: Bool = false

    @Flag(
        name: [.customLong("no-xcode-select")],
        help: "Skip selecting the new Xcode version as the current Command Line Tools."
    )
    var skipXcodeSelection: Bool = false

    @Flag(
        name: [.customLong("xip-deletion")],
        inversion: .prefixedEnableDisable,
        help: "Configure whether the downloaded XIP should be deleted after extraction or not."
    )
    var shouldDeleteXIP: Bool = true
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument)
    }

    public var defaultValueDescription: String {
        path
    }

    public static var defaultCompletionKind: CompletionKind {
        .directory
    }
}