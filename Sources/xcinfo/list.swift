//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

enum ListOption: EnumerableFlag {
    case all
    case onlyGM
    case last10
}

extension XCInfo {
    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List all available Xcode versions",
            discussion: "List all available Xcode versions available according to xcodereleases.com."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Flag
        var listOption: ListOption = .last10

        @Flag(inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList: Bool = true

        func run() throws {
            let core = xcinfoCore(verbose: globals.isVerbose, useANSI: globals.useANSI)
            core.list(showAllVersions: listOption == .all, showOnlyGMs: listOption == .onlyGM, updateList: updateList)
        }
    }
}
