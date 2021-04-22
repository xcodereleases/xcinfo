//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

struct XCInfo: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xcinfo",
        version: version,
        subcommands: [
            Info.self,
            List.self,
            Download.self,
            Install.self,
            Installed.self,
            Uninstall.self,
            Cleanup.self,
        ],
        defaultSubcommand: Info.self
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

enum XcodeVersion {
    case version(String)
    case latest

    init(_ string: String) throws {
        if string == "latest" {
            self = .latest
        } else {
            self = .version(string)
        }
    }

    func asString() -> String {
        switch self {
        case .latest:
            return "latest"
        case let .version(string):
            return string
        }
    }
}

XCInfo.main()
