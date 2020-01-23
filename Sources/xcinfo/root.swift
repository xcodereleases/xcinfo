//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka

var rootCommand = Command(
    usage: "xcinfo",
    configuration: configuration,
    run: execute
)

private func configuration(command: Command) {
    command.add(flags: [
        Flag(longName: "version",
             value: false,
             description: "Show the version number of xcinfo",
             inheritable: true),
        Flag(longName: "no-ansi",
             value: false,
             description: "Show output without ANSI codes",
             inheritable: true),
        Flag(shortName: "v",
             longName: "verbose",
             value: false,
             description: "Show more debugging information",
             inheritable: true),
    ])

    command.defaultSubcommand = infoCommand

    command.inheritablePreRun = { flags, _ in
        if flags.getBool(name: "version") == true {
            print(xcinfoVersion)
            return false
        }
        return true
    }
}

private func execute(flags _: Flags, args _: [String]) {
    print("No command specified. Will use `info`.")
    infoCommand.execute()
}
