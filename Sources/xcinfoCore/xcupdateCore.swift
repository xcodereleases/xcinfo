//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Cocoa
import Colorizer
import Combine
import Foundation
import OlympUs
import Prompt
import Run
import XCIFoundation

public class xcinfoCore {
    private let logger: Logger
    private var disposeBag = Set<AnyCancellable>()

    private lazy var api = xcreleasesAPI(baseURL: URL(string: "https://xcodereleases.com/data.json")!, logger: logger)
    private lazy var downloader = Downloader(logger: logger)

    public init(verbose: Bool, useANSI: Bool) {
        logger = Logger(isVerbose: verbose, useANSI: useANSI)
    }

    private func list(updateList: Bool) -> AnyPublisher<[XcodeRelease], Never> {
        if updateList {
            logger.verbose("Updating list of available Xcode releases from xcodereleases.com ...")
            return api.remoteList()
                .tryCatch { _ in self.api.cachedList() }
                .replaceError(with: [])
                .eraseToAnyPublisher()
        } else {
            return api.cachedList()
                .replaceError(with: [])
                .eraseToAnyPublisher()
        }
    }

    private func findXcodeReleases(for version: String?, knownVersions: [XcodeRelease]) -> [XcodeRelease] {
        var releases = knownVersions
        if let version = version {
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
            releases = releases.filter {
                if let betaVersion = betaVersion {
                    return ($0.version.number.lowercased().hasPrefix(fullVersion ?? version) &&
                        $0.version.release.beta == betaVersion) ||
                        $0.version.build.lowercased() == version
                } else {
                    return $0.version.number.lowercased().hasPrefix(fullVersion ?? version) ||
                        $0.version.build.lowercased() == version
                }
            }
        }

        return releases
    }

    private func findInstalledXcodes(for version: String?, knownVersions: [XcodeRelease]) -> [XcodeApplication] {
        var xcodes = installedXcodes(knownVersions: knownVersions)

        if let version = version {
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
            xcodes = xcodes.filter {
                if let betaVersion = betaVersion {
                    return ($0.release.version.number.lowercased().hasPrefix(fullVersion ?? version) &&
                        $0.release.version.release.beta == betaVersion) ||
                        $0.release.version.build.lowercased() == version
                } else {
                    return $0.release.version.number.lowercased().hasPrefix(fullVersion ?? version) ||
                        $0.release.version.build.lowercased() == version
                }
            }
        }

        return xcodes
    }

    func findXcodes(for version: String?, knownVersions: [XcodeRelease]) -> Future<[XcodeRelease], Never> {
        Future { promise in
            promise(.success(self.findXcodeReleases(for: version, knownVersions: knownVersions)))
        }
    }

    func findXcodes(for version: String?, knownVersions: [XcodeRelease]) -> Future<[XcodeApplication], Never> {
        Future { promise in
            promise(.success(self.findInstalledXcodes(for: version, knownVersions: knownVersions)))
        }
    }

    public func uninstall(_ version: String?) {
        list(updateList: true)
            .sink { knownVersions in
                guard !knownVersions.isEmpty else {
                    self.logger.error("No Xcode releases found.")
                    exit(EXIT_FAILURE)
                }

                let xcodes: [XcodeApplication] = self.findInstalledXcodes(for: version, knownVersions: knownVersions).sorted(by: >)

                if xcodes.isEmpty {
                    self.logger.error("No matching Xcode version found.")
                    exit(EXIT_FAILURE)
                } else {
                    let selected: XcodeApplication
                    if xcodes.count > 1 {
                        let listFormatter = ListFormatter()
                        listFormatter.locale = Locale(identifier: "en_US")
                        self.logger.verbose("Found: \(listFormatter.string(from: xcodes.map { $0.release.description })!)")

                        selected = choose("Please choose the version you want to uninstall: ", type: XcodeApplication.self) { settings in
                            let longestXcodeNameLength = xcodes.map { $0.release.description }.max(by: { $1.count > $0.count })!.count
                            for xcode in xcodes {
                                let attributedName = xcode.release.attributedDisplayName
                                let width = longestXcodeNameLength + attributedName.count - attributedName.reset().count
                                let choice = "\(attributedName.paddedWithSpaces(to: width)) – \(xcode.url.path.f.Cyan)"

                                settings.addChoice(choice) { xcode }
                            }
                        }
                    } else {
                        selected = xcodes[0]
                    }

                    if agree("Are you sure you want to uninstall Xcode \(selected.release.attributedDisplayName)?") {
                        do {
                            self.logger.verbose("Uninstalling Xcode \(selected.release.description) from \(selected.url.path) ...")
                            try FileManager.default.removeItem(at: selected.url)
                            self.logger.success("\(selected.release.description) uninstalled!")
                            exit(EXIT_SUCCESS)
                        } catch {
                            self.logger.error("Uninstallation failed. Error: \(error.localizedDescription)")
                            exit(EXIT_FAILURE)
                        }
                    } else {
                        self.logger.log("kthxbye")
                        exit(EXIT_SUCCESS)
                    }
                }
            }
            .store(in: &disposeBag)

        RunLoop.main.run()
    }

    public func list(showAllVersions: Bool, showOnlyGMs: Bool, updateList: Bool) {
        list(updateList: updateList)
            .sink(receiveCompletion: { _ in
                self.logger.error("Invalid response")
                exit(EXIT_FAILURE)
            }, receiveValue: { result in
                guard !result.isEmpty else {
                    self.logger.error("Empty result list")
                    exit(EXIT_FAILURE)
                }

                let versions = showOnlyGMs ? result.filter { $0.version.release.gm } : result

                let columnWidth = versions.map { $0.description }.max(by: { $1.count > $0.count })!.count + 12
                let installableVersions = versions.filter {
                    guard let installableOsVersion = OperatingSystemVersion(string: $0.requires) else { return false }
                    return $0.links?.download?.url != nil &&
                        ProcessInfo.processInfo.isOperatingSystemAtLeast(installableOsVersion)
                }

                let allVersions = Set(versions)

                let listedVersions = (showAllVersions ? versions : installableVersions.filter {
                    let components = DateComponents(year: -1)
                    let referenceDate = Calendar.current.date(byAdding: components, to: Date())!
                    return $0.releaseDate > referenceDate
                }).sorted(by: >)

                self.printXcodeVersionList(xcodeVersions: listedVersions.map { $0.attributedDisplayName }, columnWidth: columnWidth)

                let installedVersions = self.installedXcodes(knownVersions: versions).map { $0.release }

                if !installedVersions.isEmpty {
                    self.logger.log("\nAlready installed:")

                    self.printXcodeVersionList(xcodeVersions: installedVersions.sorted(by: >).map { $0.attributedDisplayName }, columnWidth: columnWidth)
                }

                let notInstallableVersions = allVersions.subtracting(installableVersions)
                if !notInstallableVersions.isEmpty {
                    self.logger.log("\nNot installable:")

                    self.printXcodeVersionList(xcodeVersions: notInstallableVersions.sorted(by: >).map { $0.description }, columnWidth: columnWidth)
                }

                exit(EXIT_SUCCESS)
            })
            .store(in: &disposeBag)

        RunLoop.main.run()
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
                    let width = columnWidth + xcversion.count - xcversion.reset().count
                    strings.append(xcversion.paddedWithSpaces(to: width))
                }

                logger.log(strings.joined())
            }
        } else {
            logger.log(xcodeVersions.joined(separator: "\n"))
        }
    }

    public func info(releaseName: String?) {
        list(updateList: true)
            .flatMap { knownVersions -> Future<[XcodeRelease], Never> in
                self.logger.beginSection("Identifying")
                return self.findXcodes(for: releaseName, knownVersions: knownVersions)
            }
            .mapError { _ in XCAPIError.downloadInterrupted }
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    self.logger.error("\(error.localizedDescription)")
                    exit(EXIT_FAILURE)
                }
            }, receiveValue: { xcodeVersions in
                if let xcodeVersion = self.chooseXcode(xcodeVersions, givenReleaseName: releaseName, prompt: "Please choose the exact version: ") {
                    self.logger.beginSection("Version info")
                    self.logger.log(xcodeVersion.description)

                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.dateStyle = .long

                    let relativeDateFormatter = RelativeDateTimeFormatter()
                    relativeDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    var releaseDateString = "Release date: \(dateFormatter.string(from: xcodeVersion.releaseDate))"
                    if let relativeDateString = relativeDateFormatter.string(for: xcodeVersion.releaseDate) {
                        releaseDateString += " (\(relativeDateString))"
                    }
                    self.logger.log(releaseDateString)
                    self.logger.log("Requires macOS \(xcodeVersion.requires)")

                    self.logger.beginParagraph("SDKs")

                    if let sdks = xcodeVersion.sdks {
                        let longestSDKName = sdks.map { "\($0.key) SDK:" }.max(by: { $1.count > $0.count })!.count
                        for (name, versions) in sdks {
                            let sdkName = "\(name) SDK:"
                            let version = versions[0]
                            self.logger.log("\(sdkName.paddedWithSpaces(to: longestSDKName)) \(version.build)")
                        }
                    }
                    self.logger.beginParagraph("Compilers")
                    if let compilers = xcodeVersion.compilers {
                        let longestName = compilers.map { "\($0.key) \($0.value[0].number ?? "")" }.max(by: { $1.count > $0.count })!.count
                        for (name, versions) in compilers {
                            let version = versions[0]
                            let compilerName = "\(name) \(version.number ?? "")"
                            self.logger.log("\(compilerName.paddedWithSpaces(to: longestName)): \(version.build)")
                        }
                    }

                    self.logger.beginParagraph("Links")
                    self.logger.log("Download:      " + xcodeVersion.links!.download!.url.absoluteString)
                    self.logger.log("Release Notes: " + xcodeVersion.links!.notes!.url.absoluteString)
                    exit(EXIT_SUCCESS)
                } else {
                    self.logger.log("Could not find version")
                    exit(EXIT_SUCCESS)
                }
            })
            .store(in: &disposeBag)
        RunLoop.main.run()
    }

    private func chooseXcode(_ xcodes: [XcodeRelease], givenReleaseName: String?, prompt: String) -> XcodeRelease? {
        switch xcodes.count {
        case 0:
            return nil
        case 1:
            let version = xcodes.first
            logger.log("Found matching Xcode \(version!.attributedDisplayName).")
            return xcodes.first
        default:
            if let releaseName = givenReleaseName {
                logger.log("Found multiple possiblities for the requested version '\(releaseName.f.Cyan)'.")
            } else {
                logger.log("No version was provided. You can choose between the ten latest or cancel and use an argument.")
            }

            let listedXcodeVersions = givenReleaseName == nil ? Array(xcodes.prefix(10)) : xcodes
            let selectedVersion = choose(prompt, type: XcodeRelease.self) { settings in
                for xcode in listedXcodeVersions {
                    settings.addChoice(self.logger.useANSI ? xcode.attributedDisplayName : xcode.displayName) { xcode }
                }
            }
            return selectedVersion
        }
    }

    public func install(releaseName: String?,
                        updateVersionList: Bool,
                        disableSleep: Bool,
                        skipSymlinkCreation: Bool,
                        skipXcodeSelection: Bool) {
        var knownXcodes: [XcodeRelease] = []
        var xcodeVersion: XcodeRelease?

        list(updateList: updateVersionList)
            .flatMap { knownVersions -> Future<[XcodeRelease], Never> in
                knownXcodes = knownVersions
                self.logger.beginSection("Identifying")
                return self.findXcodes(for: releaseName, knownVersions: knownVersions)
            }
            .mapError { _ in XCAPIError.downloadInterrupted }
            .flatMap { xcodes -> AnyPublisher<URL, XCAPIError> in
                xcodeVersion = self.chooseXcode(xcodes, givenReleaseName: releaseName, prompt: "Please choose the version you want to install: ")
                if let xcodeVersion = xcodeVersion, let url = xcodeVersion.links?.download?.url {
                    self.logger.log("Starting installation.")
                    return Just(url)
                        .mapError { _ in XCAPIError.downloadInterrupted }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: XCAPIError.versionNotFound)
                        .eraseToAnyPublisher()
                }
            }
            .flatMap { url -> AnyPublisher<URL, XCAPIError> in
                self.logger.beginSection("Sign in to Apple Developer")
                let (username, password) = Credentials.appleIDCredentials()
                return self.downloader.authenticate(username: username, password: password)
                    .mapError { _ in XCAPIError.downloadInterrupted }
                    .map { _ in url }
                    .eraseToAnyPublisher()
            }
            .flatMap { url -> Future<URL, XCAPIError> in
                self.logger.beginSection("Downloading")
                return
                    self.downloader.start(url: url, disableSleep: disableSleep)
            }
            .flatMap { url -> Future<URL, XCAPIError> in
                // unxip
                guard
                    let appFilename = xcodeVersion?.filename,
                    let extractor = Extractor(forReadingFromContainerAt: url, appFilename: appFilename, logger: self.logger)
                else {
                    exit(EXIT_FAILURE)
                }
                self.logger.beginSection("Extracting")
                return extractor.start()
            }
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    self.logger.error("\(error.localizedDescription)")
                    exit(EXIT_FAILURE)
                }
            }, receiveValue: { url in
                let xcodeVerification = self.verifyXcode(at: url)
                guard xcodeVerification == EXIT_SUCCESS else {
                    self.logger.error("Xcode verification failed.")
                    try? FileManager.default.removeItem(at: url)
                    exit(Int32(xcodeVerification))
                }

                self.logger.log("Installing Xcode ...")
                let password = Credentials.ask(prompt: "Password:", secure: true)

                self.enableDeveloperMode(password: password)
                self.approveLicense(password: password, url: url)
                self.installComponents(password: password, url: url)

                if !skipSymlinkCreation {
                    self.createSymbolicLink(to: url, knownXcodes: knownXcodes)
                }

                if !skipXcodeSelection {
                    self.selectXcode(at: url, password: password)
                }

                self.logger.log("Installed Xcode to \(url.path)")
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "/Applications")

                exit(EXIT_SUCCESS)
            })
            .store(in: &disposeBag)

        RunLoop.main.run()
    }

    @discardableResult public func selectXcode(at url: URL, password: String) -> Int {
        logger.verbose("Selecting Xcode...")
        let result = runSudo(command: "xcode-select", password: password, args: ["-s", url.path])
        logger.verbose("Selecting Xcode \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result)
    }

    private func createSymbolicLink(to destination: URL, knownXcodes: [XcodeRelease]) {
        let symlinkURL = URL(fileURLWithPath: "/Applications/Xcode.app")
        let fileManager = FileManager.default

        if fileManager.isSymbolicLink(atPath: symlinkURL.path) {
            logger.verbose("Symbolic link at \(symlinkURL.path) found. Removing it...")
            try? fileManager.removeItem(at: symlinkURL)
        } else if fileManager.fileExists(atPath: symlinkURL.path) {
            logger.verbose("\(symlinkURL.path) already exists. Renaming it...")

            let installed = installedXcodes(knownVersions: knownXcodes)
            if let xcode = installed.first(where: { $0.url == symlinkURL }) {
                logger.verbose("\(symlinkURL.path) already exists. Moving it to /Applications/\(xcode.release.filename).", onSameLine: true)
                let destination = URL(fileURLWithPath: "/Applications/\(xcode.release.filename)")
                try? fileManager.moveItem(at: symlinkURL, to: destination)
            }
        }

        logger.log("Creating symbolic link at \(symlinkURL.path).")
        try? fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: destination)
    }

    @discardableResult private func verifyXcode(at url: URL) -> Int {
        logger.verbose("Verifying Xcode...")
        let exitStatus = run("/usr/bin/codesign", args: ["--verify", "--verbose", url.path]).exitStatus
        logger.verbose("Verifying Xcode \(exitStatus == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return exitStatus
    }

    @discardableResult public func enableDeveloperMode(password: String) -> Int {
        logger.verbose("Enabling Developer Mode...")

        let result1 = runSudo(command: "/usr/sbin/DevToolsSecurity", password: password, args: ["-enable"])

        guard result1 == EXIT_SUCCESS else {
            logger.verbose("Enabling Developer Mode ✗")
            return Int(result1)
        }

        let result2 = runSudo(command: "/usr/sbin/dseditgroup", password: password, args: "-o edit -t group -a staff _developer".components(separatedBy: " "))

        logger.verbose("Enabling Developer Mode \(result2 == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result2)
    }

    @discardableResult public func approveLicense(password: String, url: URL) -> Int {
        logger.verbose("Approving License...")
        let result = runSudo(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-license", "accept"])
        logger.verbose("Approving License \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result)
    }

    @discardableResult public func installComponents(password: String, url: URL) -> Int {
        logger.verbose("Install additional components...")
        let result = runSudo(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-runFirstLaunch"])
        logger.verbose("Install additional components \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result)
    }

    public func cleanup() {
        logger.beginSection("Cleanup")
        logger.log("")
        do {
            let items = try KeychainPasswordItem.passwordItems(forService: "xcinfo.appleid")
            if !items.isEmpty {
                for item in items {
                    try item.deleteItem()
                }
                logger.success("Deleted stored Apple ID credentials from keychain.")
            } else {
                logger.log("No Apple ID credentials were stored.")
            }
        } catch {
            logger.error("Error deleting Keychain entries. Please open Keychain Access.app and remove items named 'xcinfo.appleid'.")
        }
        do {
            let items = try KeychainPasswordItem.passwordItems(forService: "xcinfo.session")
            if !items.isEmpty {
                for item in items {
                    try item.deleteItem()
                }
                logger.success("Deleted Apple developer portal session info from keychain.")
            } else {
                logger.log("No Apple developer portal session info was stored.")
            }
        } catch {
            logger.error("Error deleting Keychain entries. Please open Keychain Access.app and remove items named 'xcinfo.session'.")
        }
        let olymp = OlympUs(logger: logger)
        olymp.cleanupCookies()
        logger.log("Removed stored cookies.")
    }

    func runSudo(command: String, password: String, args: [String]) -> Int32 {
        let taskOne = Process()
        taskOne.launchPath = "/bin/echo"
        taskOne.arguments = [password]

        let taskTwo = Process()
        taskTwo.launchPath = "/usr/bin/sudo"
        taskTwo.arguments = ["-S", command] + args

        let pipeBetween = Pipe()
        taskOne.standardOutput = pipeBetween
        taskTwo.standardInput = pipeBetween

        taskOne.launch()
        taskOne.waitUntilExit()

        taskTwo.launch()
        taskTwo.waitUntilExit()

        return taskTwo.terminationStatus
    }

    public func installedXcodes(updateList: Bool) {
        list(updateList: updateList)
            .sink { knownVersions in
                guard !knownVersions.isEmpty else {
                    self.logger.error("No Xcode releases found.")
                    exit(EXIT_FAILURE)
                }

                let xcodes = self.installedXcodes(knownVersions: knownVersions)
                let longestXcodeNameLength = xcodes.map { $0.release.description }.max(by: { $1.count > $0.count })!.count
                xcodes.forEach {
                    let attributedName = $0.release.attributedDisplayName
                    let width = longestXcodeNameLength + attributedName.count - attributedName.reset().count
                    self.logger.log("\(attributedName.paddedWithSpaces(to: width)) – \($0.url.path.f.Cyan)")
                }

                exit(EXIT_SUCCESS)
            }.store(in: &disposeBag)

        RunLoop.main.run()
    }

    private func installedXcodes(knownVersions: [XcodeRelease]) -> [XcodeApplication] {
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
                return XcodeApplication(url: url, release: release)
            } else {
                return nil
            }
        }.sorted(by: >)
    }
}
