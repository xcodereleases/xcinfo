#if DEBUG
import Guaka
import Foundation
import xcinfoCore

var installExtractedXcodeCommand = Command(
    usage: "installExtractedXcode",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.add(flags: [
        Flag(shortName: "p",
             longName: "path",
             type: String.self,
             description: "The path to Xcode"),
        Flag(longName: "no-symlink",
             value: false,
             description: "Skip creating a symbolic link to /Applications/Xcode.app"),
        Flag(longName: "no-xcode-select",
             value: false,
             description: "Skip selecting the new Xcode version as the current Command Line Tools"),
    ])
}

private func execute(flags: Flags, args: [String]) {
    guard let path = flags.getString(name: "path") else {
        fail(statusCode: Int(EXIT_FAILURE), errorMessage: "No path specified.")
    }

    let url = URL(fileURLWithPath: path)
    guard (try? url.checkResourceIsReachable()) == true else {
        fail(statusCode: Int(EXIT_FAILURE), errorMessage: "Path invalid.")
    }

    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false
    let skipSymlinkCreation = flags.getBool(name: "no-symlink") == true
    let skipXcodeSelection = flags.getBool(name: "no-xcode-select") == true

    guard args.count <= 1 else {
        return print(installExtractedXcodeCommand.helpMessage)
    }

    let core = xcinfoCore(verbose: isVerbose, useANSI: useANSI)
    core.installXcode(from: url,
                      skipSymlinkCreation: skipSymlinkCreation,
                      skipXcodeSelection: skipXcodeSelection)
}
#endif
