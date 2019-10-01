//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import xcinfoCore

var uninstallCommand = Command(
    usage: "uninstall [version]",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "Uninstall an Xcode version"
    command.longMessage = "Uninstall a specific version of Xcode."
    command.example = #"xcinfo uninstall\#nxcinfo uninstall 11\#nxcinfo uninstall "11 Beta 5""#
    command.aliases = ["remove"]
}

private func execute(flags: Flags, args: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false

    guard args.count <= 1 else {
        return print("A VERSION argument is required.".f.Red)
    }

    let core = xcinfoCore(verbose: isVerbose, useANSI: useANSI)
    core.uninstall(args.first?.lowercased())
}
