//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import xcupdateCore

var listCommand = Command(
    usage: "list",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "List all available Xcode versions"
    command.longMessage = "List all available Xcode versions available according to xcodereleases.com."
    command.add(flags: [
        Flag(shortName: "a",
             longName: "all",
             value: false,
             description: "Show all available versions"),

        Flag(shortName: "g",
             longName: "only-gm",
             value: false,
             description: "Show only Golden Master versions"),

        Flag(longName: "no-list-update",
             value: false,
             description: "Skip updating the list of known Xcode versions before install"),
    ])
}

private func execute(flags: Flags, args _: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let showAllVersions = flags.getBool(name: "all") == true
    let useANSI = flags.getBool(name: "no-ansi") == false
    let updateVersionList = flags.getBool(name: "no-list-update") == false
    let showOnlyGMs = flags.getBool(name: "only-gm") == true

    let core = xcupdateCore(verbose: isVerbose, useANSI: useANSI)
    core.list(showAllVersions: showAllVersions, showOnlyGMs: showOnlyGMs, updateList: updateVersionList)
}
