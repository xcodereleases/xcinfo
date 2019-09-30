//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import xcupdateCore

var installCommand = Command(
    usage: "install version",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "Install an Xcode version"
    command.longMessage = "Install a specific version of Xcode."
    command.example = #"xcupdate install 11\#nxcupdate install "11 Beta 5"\#nxcupdate install 11M382q"#
    command.add(flags: [
        Flag(longName: "no-sleep",
             value: true,
             description: "Prevent system sleep during download"),
    ])

    command.add(flags: [
        Flag(longName: "no-list-update",
             value: false,
             description: "Skip updating the list of known Xcode versions before install"),
    ])

    command.add(flags: [
        Flag(longName: "no-symlink",
             value: false,
             description: "Skip creating a symbolic link to /Applications/Xcode.app"),
    ])

    command.add(flags: [
        Flag(longName: "no-xcode-select",
             value: false,
             description: "Skip selecting the new Xcode version as the current Command Line Tools"),
    ])
}

private func execute(flags: Flags, args: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false
    let disableSleep = flags.getBool(name: "no-sleep") == true
    let updateVersionList = flags.getBool(name: "no-list-update") == false
    let skipSymlinkCreation = flags.getBool(name: "no-symlink") == true
    let skipXcodeSelection = flags.getBool(name: "no-xcode-select") == true

    guard args.count <= 1 else {
        return print(installCommand.helpMessage)
    }

    let releaseName = args.first
    let core = xcupdateCore(verbose: isVerbose, useANSI: useANSI)
    core.install(releaseName: releaseName,
                 updateVersionList: updateVersionList,
                 disableSleep: disableSleep,
                 skipSymlinkCreation: skipSymlinkCreation,
                 skipXcodeSelection: skipXcodeSelection)
}
