//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

struct XCInfo: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xcinfo",
        version: "0.0.6",
        subcommands: [
            Info.self,
            List.self,
            Install.self,
            Installed.self,
            Uninstall.self,
            Cleanup.self,
            Test.self,
        ],
        defaultSubcommand: Info.self
    )
}

import Foundation

extension XCInfo {
    struct Test: ParsableCommand {
        func run() throws {
            print("First attempt")
            if let scriptObject = NSAppleScript(source: "do shell script \"xcode-select -s '/Applications/Xcode 11.4.1.app'\" with administrator privileges") {
                var error: NSDictionary?
                let output = scriptObject.executeAndReturnError(&error)

                if let error = error {
                    print("Error: \(error)")
                } else {
                    print(output.stringValue ?? "No output")
                }
            }

            print("Second attempt")
            if let scriptObject = NSAppleScript(source: "do shell script \"xcode-select -s '/Applications/Xcode.app'\" with administrator privileges") {
                var error: NSDictionary?
                let output = scriptObject.executeAndReturnError(&error)

                if let error = error {
                    print("Error: \(error)")
                } else {
                    print(output.stringValue ?? "No output")
                }
            }
        }
    }
}

struct DefaultOptions: ParsableArguments {
    @Flag(
        name: [.customLong("verbose"), .customShort("v")],
        help: "Show more debugging information."
    )
    var isVerbose: Bool

    @Flag(name: .customLong("ansi"), default: true, inversion: .prefixedNo, help: "Show output with colors.")
    var useANSI: Bool
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
