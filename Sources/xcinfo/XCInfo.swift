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
            List.self,
//            Install.self,
            Download.self,
            Installed.self,
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

}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument)
    }
}
