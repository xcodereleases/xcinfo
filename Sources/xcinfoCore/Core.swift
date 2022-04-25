//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import Run
import XCModel
import Prompt
import AppKit

public enum CoreError: LocalizedError {
    case downloadFailed(String)
    case versionNotFound(XcodeVersion)
    case invalidDownloadURL
    case extractionFailed(Error)
    case unsupportedFile(String)

    public var errorDescription: String? {
        switch self {
        case let .downloadFailed(description):
            return description
        case .invalidDownloadURL:
            return "Invalid download url"
        case .versionNotFound(let version):
            return "No Xcode found for given version '\(version)'."
        case let .extractionFailed(error):
            return "Could not extract archive. \(error.localizedDescription)"
        }
    }
}

public class Core {
    public enum ListFilter: CaseIterable {
        case onlyGM
        case onlyReleases
    }

    public struct DownloadOptions {
        public init(version: XcodeVersion, destination: URL, disableSleep: Bool) {
            self.version = version
            self.destination = destination
            self.disableSleep = disableSleep
        }

        public var version: XcodeVersion
        public var destination: URL
        public var disableSleep: Bool
    }

    public struct ExtractionOptions {
        public init(destination: URL, useExperimentalUnxip: Bool = false) {
            self.destination = destination
            self.useExperimentalUnxip = useExperimentalUnxip
        }

        public var destination: URL
        public var useExperimentalUnxip: Bool
    }

    public struct InstallationOptions {
        public init(
            downloadOptions: Core.DownloadOptions,
            extractionOptions: Core.ExtractionOptions,
            skipSymlinkCreation: Bool = false,
            skipXcodeSelection: Bool = false,
            shouldDeleteXIP: Bool = true
        ) {
            self.downloadOptions = downloadOptions
            self.extractionOptions = extractionOptions
            self.skipSymlinkCreation = skipSymlinkCreation
            self.skipXcodeSelection = skipXcodeSelection
            self.shouldDeleteXIP = shouldDeleteXIP
        }

        public var downloadOptions: DownloadOptions
        public var extractionOptions: ExtractionOptions
        public var skipSymlinkCreation = false
        public var skipXcodeSelection = false
        public var shouldDeleteXIP = true
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
            environment.logger.log("\(attributedName.paddedWithSpaces(to: width)) – \($0.url.path.cyan)")
        }
    }

    public func list(shouldUpdate: Bool, showAllVersions: Bool, filter: ListFilter?) async throws {
        let xcodes: [Xcode] = try await list(shouldUpdate: shouldUpdate)
        printXcodeList(xcodes, showAllVersions, filter)
    }

    @discardableResult
    public func download(options: DownloadOptions, updateVersionList: Bool) async throws -> (Xcode, URL) {
        environment.logger.beginSection("Identifying")
        let availableXcodes = try await findXcodes(for: options.version, shouldUpdate: updateVersionList)

        guard let xcode = chooseXcode(version: options.version, from: availableXcodes, prompt: "Please choose the version you want to install: ") else {
            throw CoreError.versionNotFound(options.version)
        }

        guard let url = xcode.links?.download?.url else {
            throw CoreError.invalidDownloadURL
        }

        environment.logger.beginSection("Sign in to Apple Developer")
        let credentials = try environment.credentialProviding.getCredentials()
        try await environment.authenticationProviding.authenticate(credentials)

        environment.logger.beginSection("Downloading")
        do {
            let downloadURL = try await environment.downloadProviding.download(url, options.destination, options.disableSleep)
            environment.logger.log("Download to \(options.destination.path) complete.")
            return (xcode, downloadURL)
        } catch let error as XCAPIError {
            throw CoreError.downloadFailed(error.description)
        }
    }

    public func install(options: InstallationOptions, updateVersionList: Bool) async throws {
        let (xcode, url) = try await download(options: options.downloadOptions, updateVersionList: updateVersionList)

        try await extractXIP(source: url, options: options.extractionOptions, xcode: xcode)
    }

    public func extractXIP(source: URL, options: ExtractionOptions, xcode: Xcode? = nil) async throws {
        environment.logger.beginSection("Extracting")
        let start = Date()
        defer {
            let end = Date()
            environment.logger.verbose("Extraction time: \(Int((end.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate).rounded(.up))) seconds.")
        }

        let extractor = Extractor(
            forReadingFromContainerAt: source,
            destination: options.destination,
            appFilename: xcode?.filename,
            logger: environment.logger
        )
        do {
            let destinationURL: URL
            if options.useExperimentalUnxip {
                destinationURL = try await extractor.extractExperimental()
            } else {
                destinationURL = try await extractor.extract()
            }
            environment.logger.log("XIP successfully extracted to \(destinationURL.path)")
        } catch let error as Extractor.ExtractionError {
            throw CoreError.extractionFailed(error.underlyingError)
        } catch {
            throw CoreError.extractionFailed(error)
        }
    }
}

extension Core {
    private func findXcodes(for version: XcodeVersion, shouldUpdate: Bool) async throws -> [Xcode] {
        let knownXcodes: [Xcode] = try await list(shouldUpdate: shouldUpdate)

        guard !knownXcodes.isEmpty else { return [] }

        switch version {
        case .version(let version):
            let (fullVersion, betaVersion) = extractVersionParts(from: version)
            return knownXcodes.filter {
                filter(xcode: $0, fullVersion: fullVersion, betaVersion: betaVersion, version: version)
            }
        case .latest:
            return [knownXcodes[0]]
        }
    }

    private func extractVersionParts(from version: String) -> (String?, Int?) {
        let pattern = #"(\d*.?\d*.?\d*) [b|B]eta ?(\d*)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        var betaVersion: Int?
        var fullVersion: String?
        if let match = regex?.firstMatch(in: version, options: [], range: NSRange(version.startIndex..., in: version)) {
            if let versionRange = Range(match.range(at: 1), in: version) {
                fullVersion = String(version[versionRange])
            }
            if let betaRange = Range(match.range(at: 2), in: version), let beta = Int(version[betaRange]) {
                betaVersion = beta
            }
        }
        return (fullVersion, betaVersion)
    }

    private func filter(xcode: Xcode, fullVersion: String?, betaVersion: Int?, version: String) -> Bool {
        if let betaVersion = betaVersion {
            let versionNumberHaveSamePrefix = xcode.version.number?.lowercased().hasPrefix(fullVersion ?? version) == true
            let betaVersionsAreSame: Bool = {
                guard case let .beta(version) = xcode.version.release else { return false }
                return version == betaVersion
            }()
            let areSameVersions = xcode.version.build?.lowercased() == version

            return versionNumberHaveSamePrefix && betaVersionsAreSame || areSameVersions
        } else {
            return xcode.version.number?.lowercased().hasPrefix(fullVersion ?? version) == true ||
            xcode.version.build?.lowercased() == version
        }
    }

    private func chooseXcode(version: XcodeVersion, from xcodes: [Xcode], prompt: String) -> Xcode? {
        switch xcodes.count {
        case 0:
            return nil
        case 1:
            let version = xcodes.first
            environment.logger.log("Found matching Xcode \(version!.attributedDisplayName).")
            return xcodes.first
        default:
            environment.logger.log("Found multiple possibilities for the requested version '\(version.description.cyan)'.")

            let selectedVersion = choose(prompt, type: Xcode.self) { settings in
                xcodes.forEach { xcode in
                    settings.addChoice(xcode.attributedDisplayName) { xcode }
                }
            }
            return selectedVersion
        }
    }

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
            environment.logger.log("Empty result list".red)
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
            environment.logger.log("\nAlready installed:")

            printXcodeVersionList(xcodeVersions: installedVersions.sorted(by: >).map { $0.attributedDisplayName }, columnWidth: columnWidth)
        }

        let notInstallableVersions = allVersions.subtracting(installableVersions)
        if !notInstallableVersions.isEmpty {
            environment.logger.log("\nNot installable:")

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

                environment.logger.log(strings.joined())
            }
        } else {
            environment.logger.log(xcodeVersions.joined(separator: "\n"))
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
