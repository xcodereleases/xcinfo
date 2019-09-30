//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Guaka
import Prompt

// Generated, don't update
func setupCommands() {
    setupHelp()

    rootCommand.add(subCommand: listCommand)
    rootCommand.add(subCommand: installCommand)
    rootCommand.add(subCommand: cleanupCommand)
    rootCommand.add(subCommand: installedCommand)
    rootCommand.add(subCommand: uninstallCommand)
    rootCommand.add(subCommand: infoCommand)
    // Command adding placeholder, edit this line
}

private func setupHelp() {
    let args = CommandLine.arguments.dropFirst()

    if args.contains("--no-ansi") {
        GuakaConfig.helpGenerator = NoAnsiColorHelpGenerator.self
        PromptSettings.printer = NoAnsiConsolePromptPrinter()
    } else {
        GuakaConfig.helpGenerator = AnsiColorHelpGenerator.self
    }
}
