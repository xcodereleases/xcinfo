//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import Run
import XCModel

public class Core {
    public enum ListFilter: CaseIterable {
        case onlyGM
        case onlyReleases
    }

    private let environment: Environment

    public init(environment: Environment) {
        self.environment = environment
    }

    public func installedXcodes(shouldUpdate: Bool) async throws {
        let knownXcodes: [Xcode] = try await list(shouldUpdate: shouldUpdate)
        let task = Task {
            installedXcodes(knownVersions: knownXcodes)
        }

        let xcodes = await task.value

        let longestXcodeNameLength = xcodes.map { $0.xcode.description }.max(by: { $1.count > $0.count })!.count
        xcodes.forEach {
            let displayVersion = $0.xcode.displayVersion
            let attributedDisplayName = "\(displayVersion) (\($0.xcode.version.build ?? ""))"

            let attributedName = attributedDisplayName.cyan
            let width = longestXcodeNameLength + attributedName.count - attributedName.raw.count
            environment.log("\(attributedName.paddedWithSpaces(to: width)) – \($0.url.path.cyan)")
        }
    }

    public func list(shouldUpdate: Bool, showAllVersions: Bool, filter: ListFilter?) async throws {
        let xcodes: [Xcode] = try await list(shouldUpdate: shouldUpdate)
        printXcodeList(xcodes, showAllVersions, filter)
    }
}

extension Core {
    private func list(shouldUpdate: Bool) async throws -> [Xcode] {
        let xcodes: [Xcode]

        if shouldUpdate {
            xcodes = try await environment.api.listXcodes()
            try await cache(xcodes)
        } else {
            xcodes = try await cachedXcodes()
        }
        return xcodes
    }

    private func installedXcodes(knownVersions: [Xcode]) -> [XcodeApplication] {
        guard !knownVersions.isEmpty else {
            return []
        }
        let result = run("mdfind kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'")
        let paths = result.stdout.split(separator: "\n")

        return paths.compactMap { path -> XcodeApplication? in
            let url = URL(fileURLWithPath: String(path))
            let versionURL = url.appendingPathComponent("Contents/version.plist")
            if let plistBuild = NSDictionary(contentsOfFile: versionURL.path)?["ProductBuildVersion"] as? String,
               let release = knownVersions.first(where: { $0.version.build == plistBuild }) {
                return XcodeApplication(url: url, xcode: release)
            } else {
                return nil
            }
        }.sorted(by: >)
    }

    private func printXcodeList(_ xcodes: [Xcode], _ showAllVersions: Bool, _ filter: ListFilter?) {
        guard !xcodes.isEmpty else {
            environment.log("Empty result list".red)
            return
        }

        let versions: [Xcode] = {
            switch filter {
            case .none:
                return xcodes
            case .onlyGM:
                return xcodes.filter { $0.version.isGM }
            case .onlyReleases:
                return xcodes.filter { $0.version.isRelease }
            }
        }()

        let columnWidth = versions.map { $0.description }.max(by: { $1.count > $0.count })!.count + 12
        let installableVersions = versions.filter {
            guard let installableOsVersion = OperatingSystemVersion(string: $0.requires) else { return false }
            return $0.links?.download?.url != nil &&
            ProcessInfo.processInfo.isOperatingSystemAtLeast(installableOsVersion)
        }

        let allVersions = Set(versions)

        let listedVersions = (showAllVersions
                ? versions
                : installableVersions.filter {
                    let components = DateComponents(year: -1)
                    let referenceDate = Calendar.current.date(byAdding: components, to: Date())!
                    return $0.releaseDate > referenceDate
                }
            )
            .sorted(by: >)

        printXcodeVersionList(xcodeVersions: listedVersions.map { $0.attributedDisplayName }, columnWidth: columnWidth)

        let installedVersions = self.installedXcodes(knownVersions: versions).map { $0.xcode }

        if !installedVersions.isEmpty {
            environment.log("\nAlready installed:")

            printXcodeVersionList(xcodeVersions: installedVersions.sorted(by: >).map { $0.attributedDisplayName }, columnWidth: columnWidth)
        }

        let notInstallableVersions = allVersions.subtracting(installableVersions)
        if !notInstallableVersions.isEmpty {
            environment.log("\nNot installable:")

            printXcodeVersionList(xcodeVersions: notInstallableVersions.sorted(by: >).map { $0.description }, columnWidth: columnWidth)
        }
    }

    private func printXcodeVersionList(xcodeVersions: [String], columnWidth: Int) {
        if xcodeVersions.count > 10,
           let windowSize = WindowSize.current {
            let cols = Int((Double(windowSize.columns) / Double(columnWidth)).rounded(.down))
            let rows = Int((Double(xcodeVersions.count) / Double(cols)).rounded(.up))

            for row in 0 ..< rows {
                var strings: [String] = []
                for col in 0 ..< cols {
                    guard row + rows * col < xcodeVersions.count else { break }
                    let xcversion = xcodeVersions[row + rows * col]
                    let width = columnWidth + xcversion.count - xcversion.raw.count
                    strings.append(xcversion.paddedWithSpaces(to: width))
                }

                environment.log(strings.joined())
            }
        } else {
            environment.log(xcodeVersions.joined(separator: "\n"))
        }
    }
}

extension Core {
    private var cacheFile: URL { environment.cachesDirectory.appendingPathComponent(.xcodesCacheFile) }

    private func cache(_ xcodes: [Xcode]) async throws {
        let task = Task {
            let data = try JSONEncoder().encode(xcodes)
            try data.write(to: cacheFile, options: .atomic)
        }

        try await task.value
    }

    private func cachedXcodes() async throws -> [Xcode] {
        let task = Task<[Xcode], Error> {
            let data = try Data(contentsOf: cacheFile)
            return try JSONDecoder().decode([Xcode].self, from: data)
        }
        let xcodes = try await task.value
        return xcodes
    }
}

private extension String {
    static let xcodesCacheFile = "xcinfo.json"
}

struct InstalledXcode {
    var path: String
    var version: Version

    init(path: String, version: Version) {
        self.path = path
        self.version = version
    }

    init?(path: String.SubSequence) {
        let path = String(path)
        let url = URL(fileURLWithPath: path)
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let versionURL = url.appendingPathComponent("Contents/version.plist")

        guard
            let shortBuildNumber = NSDictionary(contentsOf: infoPlistURL)?["CFBundleShortVersionString"] as? String,
            let plistBuild = NSDictionary(contentsOf: versionURL)?["ProductBuildVersion"] as? String
        else { return nil }

        self.init(path: path, version: .init(plistBuild, shortBuildNumber, .release))
    }
}

extension InstalledXcode {
    var displayVersion: String {
        var components: [String] = []
        if let number = version.number {
            components.append(number)
        }
        if case let .gmSeed(version) = version.release {
            components.append("GM Seed \(version)")
        } else if case let .beta(version) = version.release {
            components.append("Beta \(version)")
        } else if case let .dp(version) = version.release {
            components.append("DP \(version)")
        } else if case let .rc(version) = version.release {
            components.append("RC \(version)")
        }
        return components.joined(separator: " ")
    }
}
