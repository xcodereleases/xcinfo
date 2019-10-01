//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
import Guaka

struct NoAnsiColorHelpGenerator: HelpGenerator {
    let commandHelp: CommandHelp

    var usageSection: String? {
        let flagsString = commandHelp.hasFlags ? " [flags]" : ""

        var usageString = [
            "Usage\n",
            "  \(commandHelp.fullUsage)\(flagsString)",
        ]

        if commandHelp.hasSubCommands {
            usageString.append("  \(commandHelp.fullName) [command]")
        }

        return (usageString + ["\n"]).joined(separator: "\n").reset()
    }

    var subCommandsSection: String? {
        guard commandHelp.hasSubCommands else { return "" }

        let availableCommands = commandHelp.subCommands.filter { $0.isDeprecated == false }
        let sortedCommands = availableCommands.sorted { $0.name < $1.name }

        let longestCommand = availableCommands.max(by: { $0.name.count < $1.name.count })
        let longestCommandLength = longestCommand?.name.count ?? 0

        let ret = sortedCommands.reduce(["Available Commands\n"]) { acc, command in
            let numberOfSpaces = longestCommandLength - command.name.count
            let spaces = String(repeating: " ", count: numberOfSpaces)
            return acc + ["  \(command.name)\(spaces)    \(command.shortDescriptionMessage ?? "")"]
        } + ["\n"]

        return ret.joined(separator: "\n")
    }

    var aliasesSection: String? {
        guard !commandHelp.aliases.isEmpty else { return "" }

        return [
            "Aliases\n",
            "  \(commandHelp.name), \(commandHelp.aliases.joined(separator: ", "))",
            "\n",
        ].joined(separator: "\n")
    }

    var exampleSection: String? {
        guard let example = commandHelp.example else { return "" }

        return [
            "Examples\n  ",
            example.components(separatedBy: .newlines).map { "  \($0)" }.joined(separator: "\n"),
            "\n",
        ].joined(separator: "\n")
    }

    var flagsSection: String? {
        let hasCommands = commandHelp.globalFlags.count + commandHelp.localFlags.count > 0
        guard hasCommands else { return "" }

        var ret: [String] = []

        if let local = localFlagsSection {
            ret.append(local)
        }

        if let global = globalFlagsSection {
            ret.append(global)
        }

        return (ret + [""]).joined(separator: "\n")
    }

    var localFlagsSection: String? {
        let localFlagsDescription = XCUFlagHelpGeneratorUtils.description(forFlags: commandHelp.localFlags).reset()
        guard !localFlagsDescription.isEmpty else { return nil }

        return [
            "Flags\n",
            localFlagsDescription,
            "",
        ].joined(separator: "\n")
    }

    var globalFlagsSection: String? {
        let globalFlagsDescription = XCUFlagHelpGeneratorUtils.description(forFlags: commandHelp.globalFlags).reset()
        guard !globalFlagsDescription.isEmpty else { return nil }

        return [
            "Global Flags\n",
            globalFlagsDescription,
            "",
        ].joined(separator: "\n")
    }

    init(commandHelp: CommandHelp) {
        self.commandHelp = commandHelp
    }
}

struct AnsiColorHelpGenerator: HelpGenerator {
    let commandHelp: CommandHelp

    var usageSection: String? {
        let flagsString = commandHelp.hasFlags ? " [flags]" : ""

        var usageString = [
            "Usage\n".s.Bold.f.Cyan,
            "  \(commandHelp.fullUsage)\(flagsString)",
        ]

        if commandHelp.hasSubCommands {
            usageString.append("  \(commandHelp.fullName) [command]")
        }

        return (usageString + ["\n"]).joined(separator: "\n")
    }

    var subCommandsSection: String? {
        guard commandHelp.hasSubCommands else { return "" }

        let availableCommands = commandHelp.subCommands.filter { $0.isDeprecated == false }
        let sortedCommands = availableCommands.sorted { $0.name < $1.name }

        let longestCommand = availableCommands.max(by: { $0.name.count < $1.name.count })
        let longestCommandLength = longestCommand?.name.count ?? 0

        let ret = sortedCommands.reduce(["Available Commands\n".s.Bold.f.Cyan]) { acc, command in
            let numberOfSpaces = longestCommandLength - command.name.count
            let spaces = String(repeating: " ", count: numberOfSpaces)
            return acc + ["  \(command.name.f.Cyan)\(spaces)    \(command.shortDescriptionMessage ?? "")"]
        } + ["\n"]

        return ret.joined(separator: "\n")
    }

    var aliasesSection: String? {
        guard !commandHelp.aliases.isEmpty else { return "" }

        return [
            "Aliases\n".s.Bold.f.Cyan,
            "  \(commandHelp.name), \(commandHelp.aliases.joined(separator: ", "))",
            "\n",
        ].joined(separator: "\n")
    }

    var exampleSection: String? {
        guard let example = commandHelp.example else { return "" }

        return [
            "Examples\n".s.Bold.f.Cyan,
            example.components(separatedBy: .newlines).map { "  \($0)" }.joined(separator: "\n"),
            "\n",
        ].joined(separator: "\n")
    }

    var flagsSection: String? {
        let hasCommands = commandHelp.globalFlags.count + commandHelp.localFlags.count > 0
        guard hasCommands else { return "" }

        var ret: [String] = []

        if let local = localFlagsSection {
            ret.append(local)
        }

        if let global = globalFlagsSection {
            ret.append(global)
        }

        return (ret + [""]).joined(separator: "\n")
    }

    var localFlagsSection: String? {
        let localFlagsDescription = XCUFlagHelpGeneratorUtils.description(forFlags: commandHelp.localFlags)
        guard !localFlagsDescription.isEmpty else { return nil }

        return [
            "Flags\n".s.Bold.f.Cyan,
            localFlagsDescription,
            "",
        ].joined(separator: "\n")
    }

    var globalFlagsSection: String? {
        let globalFlagsDescription = XCUFlagHelpGeneratorUtils.description(forFlags: commandHelp.globalFlags)
        guard !globalFlagsDescription.isEmpty else { return nil }

        return [
            "Global Flags\n".s.Bold.f.Cyan,
            globalFlagsDescription,
            "",
        ].joined(separator: "\n")
    }

    init(commandHelp: CommandHelp) {
        self.commandHelp = commandHelp
    }
}

enum XCUFlagHelpGeneratorUtils {
    /// Generate a string message for the list of flag
    ///
    /// - parameter flags: flags to generate help for
    static func description(forFlags flags: [FlagHelp]) -> String {
        let notDeprecatedFlags = flags.filter { $0.isDeprecated == false }

        guard !notDeprecatedFlags.isEmpty else { return "" }

        let longestFlagName =
            notDeprecatedFlags.map { flagPrintableName(flag: $0) }
            .sorted { $0.count < $1.count }
            .last!.count

        let names =
            notDeprecatedFlags.map { flag -> String in
                let printableName = flagPrintableName(flag: flag)
                let diff = longestFlagName - printableName.count
                let addition = String(repeating: " ", count: diff)
                return "\(printableName)\(addition)  "
            }

        let descriptions = notDeprecatedFlags.map { flagPrintableDescription(flag: $0) }

        return zip(names, descriptions).map { $0 + $1 }.joined(separator: "\n")
    }

    /// Return the flag printable name
    static func flagPrintableName(flag: FlagHelp) -> String {
        var nameParts: [String] = []

        nameParts.append("  ")
        if let shortName = flag.shortName {
            nameParts.append("-\(shortName), ")
        } else {
            nameParts.append("    ")
        }

        nameParts.append("--\(flag.longName)")
        nameParts.append(" \(flag.typeDescription)")

        return nameParts.joined().f.Magenta
    }

    /// Return the flag printable description
    static func flagPrintableDescription(flag: FlagHelp) -> String {
        guard !flag.description.isEmpty else { return flagValueDescription(flag: flag) }

        return "\(flag.description) \(flagValueDescription(flag: flag))"
    }

    static func flagValueDescription(flag: FlagHelp) -> String {
        guard !flag.isBoolean else { return "" }

        if let value = flag.value {
            return "(default \(value))"
        }

        if flag.isRequired {
            return "(required)"
        }

        return ""
    }
}
