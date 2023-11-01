//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import Foundation
import xcinfoCore

@main
struct XCInfo: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xcinfo",
        version: version,
        subcommands: [
            Cleanup.self,
            Download.self,
            Extract.self,
            Info.self,
            Install.self,
            Installed.self,
            List.self,
            Uninstall.self
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

struct VersionOptions: ParsableArguments {
    @Argument(
        help: "A version number of an Xcode version or `latest`.",
        transform: XcodeVersion.init
    )
    var xcodeVersion: XcodeVersion
}

struct DownloadOptions: ParsableArguments {
    @Option(
        name: [.long, .short],
        help: "The download destination folder.",
        completion: .directory
    )
    var downloadDirectory: URL = .init(fileURLWithPath: "\(NSHomeDirectory())/Downloads").standardizedFileURL

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
        help: "The directory to install the code version in.",
        completion: .directory
    )
    var installationDirectory: URL = .init(fileURLWithPath: "/Applications")

    @Flag(
        help: "Uses system (much slower) version of unxip."
    )
    var useSystemUnxip: Bool = false
}

struct InstallationOptions: ParsableArguments {
    @OptionGroup
    var versionOptions: VersionOptions

    @Option(
        name: [.customLong("xip-path")],
        help: "The path to an existing XIP file.",
        completion: .file(extensions: ["xip"])
    )
    var xipFile: URL?

    @OptionGroup
    var downloadOptions: DownloadOptions

    @OptionGroup
    var extractionOptions: ExtractionOptions

    @Flag(
        name: [.customLong("preserve-xip")],
        help: "Skip deletion of the downloaded XIP after extraction."
    )
    var shouldPreserveXIP: Bool = false

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
