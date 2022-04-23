//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import ArgumentParser
import xcinfoCore

extension Core.ListFilter: EnumerableFlag {}

extension XCInfo {
    struct List: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List all available Xcode versions",
            discussion: "List all available Xcode versions available according to xcodereleases.com."
        )

        @OptionGroup()
        var globals: DefaultOptions

        @Flag
        var listFilter: Core.ListFilter?

        @Flag(
            name: [.customLong("all"), .customShort("a")],
            help: "Shows all Xcode version ever released. If false or omitted, only installable versions of the last year are printed."
        )
        var showAllVersions = false

        @Flag(
            inversion: .prefixedNo,
            help: "Update the list of known Xcode versions."
        )
        var updateList = true

        func run() async throws {
            let core = Core(environment: .live)
            try await core.list(shouldUpdate: updateList, showAllVersions: showAllVersions, filter: listFilter)
        }
    }
}
