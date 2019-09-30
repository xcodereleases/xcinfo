//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import xcupdateCore

var infoCommand = Command(
    usage: "info",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.shortMessage = "Xcode version info"
    command.longMessage = "Display information like SDK, release note link, etc of an Xcode version."
    command.example = #"xcupdate info 11\#nxcupdate info "11 Beta 5"\#nxcupdate info 11M382q"#
}

private func execute(flags: Flags, args: [String]) {
    let isVerbose = flags.getBool(name: "verbose") == true
    let useANSI = flags.getBool(name: "no-ansi") == false

    guard args.count <= 1 else {
        return print(installCommand.helpMessage)
    }

    let releaseName = args.first
    let core = xcupdateCore(verbose: isVerbose, useANSI: useANSI)
    core.info(releaseName: releaseName)
}
