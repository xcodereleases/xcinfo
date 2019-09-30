//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import xcupdateCore

var cleanupCommand = Command(
    usage: "cleanup",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "Remove stored credentials"
    command.longMessage = "Remove stored Apple ID credentials and session authentification items from the macOS keychain."
}

private func execute(flags: Flags, args _: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false

    let core = xcupdateCore(verbose: isVerbose, useANSI: useANSI)
    core.cleanup()
}
