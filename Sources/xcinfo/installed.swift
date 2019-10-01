//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import Guaka
import Run
import XCIFoundation
import xcinfoCore

var installedCommand = Command(
    usage: "installed",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "Show installed Xcode versions"
    command.longMessage = "Show all installed versions of Xcode and their location on this computer."
    command.add(flags: [
        Flag(longName: "no-list-update",
             value: false,
             description: "Skip updating the list of Xcode versions before running the command"),
    ])
}

private func execute(flags: Flags, args _: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false
    let updateVersionList = flags.getBool(name: "no-list-update") == false

    let core = xcinfoCore(verbose: isVerbose, useANSI: useANSI)
    core.installedXcodes(updateList: updateVersionList)
}
