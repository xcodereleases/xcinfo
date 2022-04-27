//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import XCModel
import Prompt
import AppKit

public enum CoreError: LocalizedError {
    case authenticationFailed
    case downloadFailed(String)
    case versionNotFound(XcodeVersion)
    case invalidDownloadURL
    case extractionFailed(Error)
    case unsupportedFile(String)
    case installationFailed
    case gatekeeperVerificationFailed(URL)
    case codesignVerificationFailed(URL)
    case incorrectSuperUserPassword
    case uninstallationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication with Apple failed."
        case let .downloadFailed(description), let .uninstallationFailed(description):
            return description
        case .invalidDownloadURL:
            return "Invalid download url"
        case .versionNotFound(let version):
            return "No Xcode found for given version '\(version)'."
        case let .extractionFailed(error):
            return error.localizedDescription
        case let .unsupportedFile(fileExtension):
            return "'\(fileExtension)' is not supported."
        case .installationFailed:
            return "Xcode could not be installed."
        case let .gatekeeperVerificationFailed(url):
            return "Gatekeeper could not verify Xcode at \(url.path)"
        case let .codesignVerificationFailed(url):
            return "Code sign could not verify Xcode at \(url.path)"
        case .incorrectSuperUserPassword:
            return ""
        }
    }
}

public class Core {
    public enum ListFilter: CaseIterable {
        case onlyGM
        case onlyReleases
    }

    public struct VersionOptions {
        public init(version: XcodeVersion) {
            self.version = version
        }

        public var version: XcodeVersion
    }

    public struct DownloadOptions {
        public init(destination: URL, disableSleep: Bool) {
            self.destination = destination
            self.disableSleep = disableSleep
        }

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
            version: XcodeVersion,
            xipFile: URL?,
            downloadOptions: Core.DownloadOptions,
            extractionOptions: Core.ExtractionOptions,
            skipSymlinkCreation: Bool = false,
            skipXcodeSelection: Bool = false,
            shouldPreserveXIP: Bool = false
        ) {
            self.version = version
            self.xipFile = xipFile
            self.downloadOptions = downloadOptions
            self.extractionOptions = extractionOptions
            self.skipSymlinkCreation = skipSymlinkCreation
            self.skipXcodeSelection = skipXcodeSelection
            self.shouldPreserveXIP = shouldPreserveXIP
        }

        public var version: XcodeVersion
        public var xipFile: URL?
        public var downloadOptions: DownloadOptions
        public var extractionOptions: ExtractionOptions
        public var skipSymlinkCreation = false
        public var skipXcodeSelection = false
        public var shouldPreserveXIP = true
    }

    private let environment: Environment

    public init(environment: Environment) {
        self.environment = environment
    }

    public func info(version: XcodeVersion, shouldUpdate _: Bool) async throws {
        let xcode = try await identifyVersion(version, updateVersionList: true)

        environment.logger.beginSection("Version info")
        environment.logger.log(xcode.description)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateStyle = .long

        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var releaseDateString = "Release date: \(dateFormatter.string(from: xcode.releaseDate))"
        if let relativeDateString = relativeDateFormatter.string(for: xcode.releaseDate) {
            releaseDateString += " (\(relativeDateString))"
        }
        environment.logger.log(releaseDateString)
        environment.logger.log("Requires macOS \(xcode.requires)")

        environment.logger.beginParagraph("SDKs")

        if let sdks = xcode.sdks?.keyed() {
            let longestSDKName = sdks.map { "\($0.key) SDK:" }.max(by: { $1.count > $0.count })!.count
            for (name, versions) in sdks {
                let sdkName = "\(name) SDK:"
                let version = versions[0]
                environment.logger.log("\(sdkName.paddedWithSpaces(to: longestSDKName)) \(version.build ?? "")")
            }
        }
        environment.logger.beginParagraph("Compilers")
        if let compilers = xcode.compilers?.keyed() {
            let longestName = compilers.map { "\($0.key) \($0.value[0].number ?? ""):" }
                .max(by: { $1.count > $0.count })!.count
            for (name, versions) in compilers {
                let version = versions[0]
                let compilerName = "\(name) \(version.number ?? ""):"
                environment.logger.log("\(compilerName.paddedWithSpaces(to: longestName)) \(version.build ?? "")")
            }
        }

        environment.logger.beginParagraph("Links")
        environment.logger.log("Download:      " + xcode.links!.download!.url.absoluteString)
        environment.logger.log("Release Notes: " + xcode.links!.notes!.url.absoluteString)
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
    public func download(version: XcodeVersion, options: DownloadOptions, updateVersionList: Bool) async throws -> (Xcode, URL) {
        let xcode = try await identifyVersion(version, updateVersionList: true)

        guard let url = xcode.links?.download?.url else {
            throw CoreError.invalidDownloadURL
        }

        environment.logger.beginSection("Sign in to Apple Developer")
        let credentials = try environment.credentialProviding.getCredentials()
        do {
            try await environment.authenticationProviding.authenticate(credentials)
        } catch {
            throw CoreError.authenticationFailed
        }

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
        typealias DownloadResult = (xcode: Xcode, url: URL)

        let downloadResult: DownloadResult

        if let url = options.xipFile {
            let xcode = try await identifyVersion(options.version, updateVersionList: true)
            downloadResult = (xcode, url)
        } else {
            downloadResult = try await download(version: options.version, options: options.downloadOptions, updateVersionList: updateVersionList)
        }

        let app = try await extractXIP(source: downloadResult.url, options: options.extractionOptions, xcode: downloadResult.xcode)

        if !options.shouldPreserveXIP {
            try deleteDownload(at: downloadResult.url)
        }

        guard let app = app else {
            throw CoreError.installationFailed
        }

        try await installXcode(app, options: options)
    }

    public func uninstall(_ version: String?, updateVersionList: Bool) async throws {
        let knownVersions: [Xcode] = try await list(shouldUpdate: updateVersionList)
        guard !knownVersions.isEmpty else {
            throw CoreError.uninstallationFailed("No Xcode releases found.")
        }

        let xcodes: [XcodeApplication] = findInstalledXcodes(for: version, knownVersions: knownVersions).sorted(by: >)

        if xcodes.isEmpty {
            throw CoreError.uninstallationFailed("No matching Xcode version found.")
        } else {
            let selected: XcodeApplication
            if xcodes.count > 1 {
                let listFormatter = ListFormatter()
                listFormatter.locale = Locale(identifier: "en_US")
                environment.logger.verbose("Found: \(listFormatter.string(from: xcodes.map { $0.xcode.description })!)")

                selected = choose("Please choose the version you want to uninstall: ", type: XcodeApplication.self) { settings in
                    let longestXcodeNameLength = xcodes.map { $0.xcode.attributedDisplayName }.max(by: { $1.count > $0.count })!.count
                    for xcodeApp in xcodes {
                        let attributedName = xcodeApp.xcode.attributedDisplayName
                        let width = longestXcodeNameLength + attributedName.count - attributedName.raw.count
                        let choice = "\(attributedName.paddedWithSpaces(to: width)) – \(xcodeApp.url.path.cyan)"

                        settings.addChoice(choice) { xcodeApp }
                    }
                }
            } else {
                selected = xcodes[0]
            }

            let displayName = selected.xcode.attributedDisplayName
            if agree("Are you sure you want to uninstall Xcode \(displayName)?") {
                do {
                    environment.logger.verbose("Uninstalling Xcode \(selected.xcode.description) from \(selected.url.path) ...")
                    try FileManager.default.removeItem(at: selected.url)
                    environment.logger.success("\(selected.xcode.description) uninstalled!")
                } catch {
                    throw CoreError.uninstallationFailed("Uninstallation failed. Error: \(error.localizedDescription)")
                }
            } else {
                environment.logger.log("kthxbye")
            }
        }
    }


    @discardableResult
    public func extractXIP(source: URL, options: ExtractionOptions, xcode: Xcode? = nil) async throws -> XcodeApplication? {
        environment.logger.beginSection("Extracting")

        guard source.pathExtension.lowercased() == "xip" else {
            throw CoreError.unsupportedFile(source.pathExtension)
        }

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
            guard let xcode = xcode else { return nil }
            return .init(url: destinationURL, xcode: xcode)
        } catch {
            throw CoreError.extractionFailed(error)
        }
    }

    public func cleanup() {
        environment.logger.beginSection("Cleanup")
        environment.logger.log("")
        environment.credentialProviding.cleanup()
        environment.downloadProviding.cleanup()
        environment.api.removeCookies()

        environment.logger.log("Removed stored cookies.")
    }
}

extension Core {
    private func identifyVersion(_ version: XcodeVersion, updateVersionList: Bool) async throws -> Xcode {
        environment.logger.beginSection("Identifying")
        let availableXcodes = try await findXcodes(for: version, shouldUpdate: updateVersionList)

        guard let xcode = chooseXcode(version: version, from: availableXcodes, prompt: "Please choose the version you want to install: ") else {
            throw CoreError.versionNotFound(version)
        }
        return xcode
    }

    private func installXcode(_ xcode: XcodeApplication, options: InstallationOptions) async throws {
        environment.logger.beginSection("Installing")

        try verify(xcode)

        let password = try getPassword()

        try enableDeveloperMode(password: password)
        try approveLicense(password: password, url: xcode.url)
        try installComponents(password: password, url: xcode.url)

        if !options.skipSymlinkCreation {
            try await createSymbolicLink(to: xcode.url)
        }

        if !options.skipXcodeSelection {
            try selectXcode(at: xcode.url, password: password)
        }

        environment.logger.log("Installed Xcode to \(xcode.url.path)")
        NSWorkspace.shared.selectFile(xcode.url.path, inFileViewerRootedAtPath: xcode.url.deletingLastPathComponent().path)
    }

    private func enableDeveloperMode(password: String) throws {
        environment.logger.log("Enabling Developer Mode...")

        let result1 = Shell.executePrivileged(command: "/usr/sbin/DevToolsSecurity", password: password, args: ["-enable"]).exitStatus

        guard result1 == EXIT_SUCCESS else {
            environment.logger.log("Enabling Developer Mode \("✗".red)", onSameLine: true)
            throw CoreError.installationFailed
        }

        let result2 = Shell.executePrivileged(command: "/usr/sbin/dseditgroup", password: password, args: "-o edit -t group -a staff _developer".components(separatedBy: " ")).exitStatus

        guard result2 == EXIT_SUCCESS else {
            environment.logger.log("Enabling Developer Mode \("✗".red)", onSameLine: true)
            throw CoreError.installationFailed
        }

        environment.logger.log("Enabling Developer Mode \("✓".cyan)", onSameLine: true)
    }

    private func approveLicense(password: String, url: URL) throws {
        environment.logger.log("Approving License...")
        let result = Shell.executePrivileged(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-license", "accept"]).exitStatus

        guard result == EXIT_SUCCESS else {
            environment.logger.log("Approving License \("✗".red)", onSameLine: true)
            throw CoreError.installationFailed
        }

        environment.logger.log("Approving License \("✓".cyan)", onSameLine: true)
    }

    private func installComponents(password: String, url: URL) throws {
        environment.logger.log("Install additional components...")
        let result = Shell.executePrivileged(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-runFirstLaunch"]).exitStatus

        guard result == EXIT_SUCCESS else {
            environment.logger.log("Install additional components \("✗".red)", onSameLine: true)
            throw CoreError.installationFailed
        }

        environment.logger.log("Install additional components \("✓".cyan)", onSameLine: true)
    }

    private func createSymbolicLink(to destination: URL) async throws {
        let symlinkURL = URL(fileURLWithPath: "/Applications/Xcode.app")
        let fileManager = FileManager.default

        if fileManager.isSymbolicLink(atPath: symlinkURL.path) {
            environment.logger.verbose("Symbolic link at \(symlinkURL.path) found. Removing it...")
            try? fileManager.removeItem(at: symlinkURL)
        } else if fileManager.fileExists(atPath: symlinkURL.path) {
            environment.logger.verbose("\(symlinkURL.path) already exists. Renaming it...")

            let knownXcodes = try await list(shouldUpdate: false)
            let installed = installedXcodes(knownVersions: knownXcodes)

            if let xcodeApp = installed.first(where: { $0.url == symlinkURL }) {
                environment.logger.verbose("\(symlinkURL.path) already exists. Moving it to /Applications/\(xcodeApp.xcode.filename).", onSameLine: true)
                let destination = URL(fileURLWithPath: "/Applications/\(xcodeApp.xcode.filename)")
                try? fileManager.moveItem(at: symlinkURL, to: destination)
            }
        }

        environment.logger.log("Creating symbolic link at \(symlinkURL.path).")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: destination)
        environment.logger.log("Creating symbolic link at \(symlinkURL.path). \("✓".cyan)", onSameLine: true)
    }

    func selectXcode(at url: URL, password: String) throws {
        environment.logger.log("Selecting Xcode...")
        let result = Shell.executePrivileged(command: "xcode-select", password: password, args: ["-s", url.path]).exitStatus

        guard result == EXIT_SUCCESS else {
            environment.logger.log("Selecting Xcode \("✗".red)", onSameLine: true)
            throw CoreError.installationFailed
        }

        environment.logger.log("Selecting Xcode \("✓".cyan)", onSameLine: true)
    }

    private func getPassword() throws -> String {
        environment.logger.log("XCInfo needs super user privileges in order to proceed.")

        var passwordAttempts = 0
        let maxPasswordAttempts = 3
        var possiblePassword: String?
        repeat {
            passwordAttempts += 1
            let prompt: String = {
                if passwordAttempts == 1 {
                    return "Please enter your password:"
                } else {
                    return "Sorry, try again:"
                }
            }()

            func getPwd(prompt: String) -> String? {
                do {
                    let password = try Shell.ask(prompt, secure: true) { pwd in
                        let sudoExitStatus = Shell.executePrivileged(command: "ls", password: pwd, args: []).exitStatus
                        return sudoExitStatus == EXIT_SUCCESS
                    }
                    return password
                } catch {
                    return nil
                }
            }
            possiblePassword = getPwd(prompt: prompt)
        } while possiblePassword == nil && passwordAttempts < maxPasswordAttempts

        guard let password = possiblePassword else {
            environment.logger.verbose("3rd incorrect password attempt. Terminating...")
            throw CoreError.incorrectSuperUserPassword
        }
        return password
    }

    private func verify(_ app: XcodeApplication) throws {
        environment.logger.log("Verifying Xcode...")
        var exitStatus = Shell.execute("/usr/sbin/spctl", args: "--assess", "--verbose", "--type", "execute", app.url.path).exitStatus
        guard exitStatus == EXIT_SUCCESS else {
            throw CoreError.gatekeeperVerificationFailed(app.url)
        }

        exitStatus = Shell.execute("/usr/bin/codesign", args: "--verify", "--verbose", app.url.path).exitStatus

        guard exitStatus == EXIT_SUCCESS else {
            throw CoreError.codesignVerificationFailed(app.url)
        }

        environment.logger.log("Verifying Xcode \("✓".cyan)", onSameLine: true)
    }

    private func deleteDownload(at url: URL)  throws {
        environment.logger.log("Deleting downloaded Xcode archive...")
        try FileManager.default.removeItem(at: url)
    }

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

    private func findInstalledXcodes(for version: String?, knownVersions: [Xcode]) -> [XcodeApplication] {
        var xcodesApplications = installedXcodes(knownVersions: knownVersions)
        if let version = version {
            let (fullVersion, betaVersion) = extractVersionParts(from: version)
            xcodesApplications = xcodesApplications.filter {
                filter(xcode: $0.xcode, fullVersion: fullVersion, betaVersion: betaVersion, version: version)
            }
        }
        return xcodesApplications
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
        let result = Shell.execute("mdfind", args: "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'")
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
