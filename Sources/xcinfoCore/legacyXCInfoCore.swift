//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Cocoa
import Rainbow
import Combine
import Foundation
import OlympUs
import Prompt
import XCIFoundation
import XCModel

func fail(statusCode: Int, errorMessage: String? = nil) -> Never {
    if let errorMessage = errorMessage {
        print(errorMessage)
    }
    exit(Int32(statusCode))
}

public class legacyXCInfoCore {
    private let logger: Logger
    private var disposeBag = Set<AnyCancellable>()

    private let session: URLSession
    private let sessionDelegateProxy = URLSessionDelegateProxy()

    private lazy var api = XCReleasesAPI(baseURL: URL(string: "https://xcodereleases.com/data.json")!, session: session)

    private lazy var olymp = OlympUs(logger: logger, session: session)
    private lazy var authenticaotr = AppleAuthenticator(olymp: olymp, logger: logger)
    private lazy var downloader = Downloader(logger: logger, olymp: olymp, sessionDelegateProxy: sessionDelegateProxy)

    private var interruptionHandler: InterruptionHandler?

    public init(verbose: Bool, useANSI: Bool) {
        Rainbow.enabled = useANSI
        logger = Logger(isVerbose: verbose)
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = .shared
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config, delegate: sessionDelegateProxy, delegateQueue: nil)
    }

    private func list(updateList: Bool) -> AnyPublisher<[Xcode], Never> {
        if updateList {
            logger.verbose("Updating list of available Xcode releases from Xcodes.com ...")
            return api.remoteList()
                .tryCatch { error -> Future<[Xcode], XCAPIError> in
                    self.logger.verbose("Could not update the list: \(error).")
                    return self.api.cachedList()
                }
                .replaceError(with: [])
                .eraseToAnyPublisher()
        } else {
            return api.cachedList()
                .replaceError(with: [])
                .eraseToAnyPublisher()
        }
    }

    private func findXcodes(for version: String?, knownVersions: [Xcode]) -> [Xcode] {
        var releases = knownVersions
        if let version = version {
            if version == "latest", let latest = releases.first {
                releases = [latest]
            } else {
                let (fullVersion, betaVersion) = extractVersionParts(from: version)
                releases = releases.filter {
                    filter(xcode: $0, fullVersion: fullVersion, betaVersion: betaVersion, version: version)
                }
            }
        }
        return releases
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

    func findXcodes(for version: String?, knownVersions: [Xcode]) -> Future<[Xcode], Never> {
        Future { promise in
            promise(.success(self.findXcodes(for: version, knownVersions: knownVersions)))
        }
    }

    func findXcodes(for version: String?, knownVersions: [Xcode]) -> Future<[XcodeApplication], Never> {
        Future { promise in
            promise(.success(self.findInstalledXcodes(for: version, knownVersions: knownVersions)))
        }
    }

    public func uninstall(_ version: String?, updateVersionList: Bool) {
        list(updateList: updateVersionList)
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
                        self.logger.verbose("Found: \(listFormatter.string(from: xcodes.map { $0.xcode.description })!)")

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
                            self.logger.verbose("Uninstalling Xcode \(selected.xcode.description) from \(selected.url.path) ...")
                            try FileManager.default.removeItem(at: selected.url)
                            self.logger.success("\(selected.xcode.description) uninstalled!")
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

                let versions = showOnlyGMs ? result.filter { $0.version.isGM } : result

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

                let installedVersions = self.installedXcodes(knownVersions: versions).map { $0.xcode }

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
                    let width = columnWidth + xcversion.count - xcversion.raw.count
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
            .flatMap { knownVersions -> Future<[Xcode], Never> in
                self.logger.beginSection("Identifying")
                return self.findXcodes(for: releaseName, knownVersions: knownVersions)
            }
            .sink { xcodeVersions in
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

                    if let sdks = xcodeVersion.sdks?.keyed() {
                        let longestSDKName = sdks.map { "\($0.key) SDK:" }.max(by: { $1.count > $0.count })!.count
                        for (name, versions) in sdks {
                            let sdkName = "\(name) SDK:"
                            let version = versions[0]
                            self.logger.log("\(sdkName.paddedWithSpaces(to: longestSDKName)) \(version.build ?? "")")
                        }
                    }
                    self.logger.beginParagraph("Compilers")
                    if let compilers = xcodeVersion.compilers?.keyed() {
                        let longestName = compilers.map { "\($0.key) \($0.value[0].number ?? ""):" }.max(by: { $1.count > $0.count })!.count
                        for (name, versions) in compilers {
                            let version = versions[0]
                            let compilerName = "\(name) \(version.number ?? ""):"
                            self.logger.log("\(compilerName.paddedWithSpaces(to: longestName)) \(version.build ?? "")")
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
            }
            .store(in: &disposeBag)
        RunLoop.main.run()
    }

    private func chooseXcode(_ xcodes: [Xcode], givenReleaseName: String?, prompt: String) -> Xcode? {
        switch xcodes.count {
        case 0:
            return nil
        case 1:
            let version = xcodes.first
            logger.log("Found matching Xcode \(version!.attributedDisplayName).")
            return xcodes.first
        default:
            if let releaseName = givenReleaseName {
                logger.log("Found multiple possibilities for the requested version '\(releaseName.cyan)'.")
            } else {
                logger.log("No version was provided. You can choose between the ten latest or cancel and use an argument.")
            }

            let listedXcodeVersions = givenReleaseName == nil ? Array(xcodes.prefix(10)) : xcodes
            let selectedVersion = choose(prompt, type: Xcode.self) { settings in
                for xcode in listedXcodeVersions {
                    settings.addChoice(xcode.attributedDisplayName) { xcode }
                }
            }
            return selectedVersion
        }
    }

    public func download(releaseName: String?,
                         updateVersionList: Bool,
                         disableSleep: Bool) {
        download(releaseName: releaseName, updateVersionList: updateVersionList, disableSleep: disableSleep)
            .sink { [unowned self] completion in
                if case let .failure(error) = completion {
                    logger.error("Error: \(error)")
                    exit(EXIT_FAILURE)
                } else {
                    exit(EXIT_SUCCESS)
                }
            } receiveValue: { [unowned self] (url, _, _) in
                logger.success("Successfully downloaded to: \(url.path)")
            }
            .store(in: &disposeBag)

        RunLoop.main.run()
    }

    func download(releaseName: String?,
                  updateVersionList: Bool,
                  disableSleep: Bool) -> AnyPublisher<(URL, [Xcode], Xcode?), XCAPIError> {
        var knownXcodes: [Xcode] = []
        var xcodeVersion: Xcode?

        return list(updateList: updateVersionList)
            .flatMap { knownVersions -> Future<[Xcode], Never> in
                knownXcodes = knownVersions
                self.logger.beginSection("Identifying")
                return self.findXcodes(for: releaseName, knownVersions: knownVersions)
            }
            .setFailureType(to: XCAPIError.self)
            .flatMap { xcodes -> AnyPublisher<URL, XCAPIError> in
                var selectableXcodes = xcodes
                var releaseName = releaseName
                if xcodes.isEmpty {
                    selectableXcodes = knownXcodes
                    releaseName = nil
                }
                xcodeVersion = self.chooseXcode(selectableXcodes, givenReleaseName: releaseName, prompt: "Please choose the version you want to install: ")
                if let xcodeVersion = xcodeVersion, let url = xcodeVersion.links?.download?.url {
                    self.logger.log("Starting installation.")
                    return Just(url)
                        .setFailureType(to: XCAPIError.self)
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: XCAPIError.versionNotFound)
                        .eraseToAnyPublisher()
                }
            }
            .flatMap { url -> AnyPublisher<URL, XCAPIError> in
                self.logger.beginSection("Sign in to Apple Developer")
                let (username, password) = Credentials.appleIDCredentials()
                return self.authenticaotr.authenticate(username: username, password: password)
                    .mapError { _ in XCAPIError.downloadInterrupted }
                    .map { _ in url }
                    .eraseToAnyPublisher()
            }
            .flatMap { url -> AnyPublisher<(URL, [Xcode], Xcode?), XCAPIError> in
                self.logger.beginSection("Downloading")

                func download(url: URL, resumeData: Data? = nil) -> AnyPublisher<URL, XCAPIError> {
                    return self.downloader.start(url: url, disableSleep: disableSleep, resumeData: resumeData)
                        .catch { error -> AnyPublisher<URL, XCAPIError> in
                            guard case let XCAPIError.recoverableDownloadError(url, resumeData) = error else {
                                return Fail(error: error).eraseToAnyPublisher()
                            }

                            return Just(())
                                .setFailureType(to: XCAPIError.self)
                                .delay(for: .seconds(3), scheduler: DispatchQueue.global())
                                .flatMap {
                                    download(url: url, resumeData: resumeData)
                                }
                                .eraseToAnyPublisher()
                        }.eraseToAnyPublisher()
                }

                self.setDownloadInterruptionHandler()

                let resumeData = self.downloader.cacheURL(for: url).flatMap { try? Data(contentsOf: $0) }
                return download(url: url, resumeData: resumeData).handleEvents(receiveCompletion: {
                    self.interruptionHandler = nil
                    if case .finished = $0 {
                        self.downloader.removeCachedResumeData(for: url)
                    }
                })
                .map { url in
                    (url, knownXcodes, xcodeVersion)
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    public func install(releaseName: String?,
                        updateVersionList: Bool,
                        disableSleep: Bool,
                        skipSymlinkCreation: Bool,
                        skipXcodeSelection: Bool,
                        shouldDeleteXIP: Bool) {
        download(releaseName: releaseName, updateVersionList: updateVersionList, disableSleep: disableSleep)
            .mapError { error in
                return error as Error
            }
            .flatMap { downloadURL, knownXcodes, xcodeVersion -> AnyPublisher<(URL, [Xcode]), Error> in
                // unxip
                guard
                    let appFilename = xcodeVersion?.filename
                else {
                    exit(EXIT_FAILURE)
                }
                self.logger.beginSection("Extracting")
                let extractor = Extractor(
                    forReadingFromContainerAt: downloadURL,
                    destination: URL(fileURLWithPath: "/Applications"),
                    appFilename: appFilename,
                    logger: self.logger
                )
                return extractor.start()
                    .map { url in
                        (url, knownXcodes)
                    }
                    .handleEvents(receiveCompletion: { completion in
                        if case .finished = completion, shouldDeleteXIP {
                            try? FileManager.default.removeItem(at: downloadURL)
                        }
                    })
                    .eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    self.logger.error("\(error)")
                    exit(EXIT_FAILURE)
                }
            }, receiveValue: { (url, knownXcodes) in
                self.installXcode(from: url,
                                  knownXcodes: knownXcodes,
                                  skipSymlinkCreation: skipSymlinkCreation,
                                  skipXcodeSelection: skipXcodeSelection)
            })
            .store(in: &disposeBag)

        RunLoop.main.run()
    }

    private func setDownloadInterruptionHandler() {
        interruptionHandler = .init { [weak self] interrupted in
            if interrupted {
                exit(EXIT_FAILURE)
            } else {
                guard let self = self else {
                    return
                }

                print()
                self.logger.log("Saving downloaded data...")

                self.olymp.session.getTasksWithCompletionHandler { _, _, downloads in
                    for download in downloads {
                        // calling this method instead of URLSessionTask's cancel() allows to caught and
                        // extract resume data from cancellation URLError in FileDownload
                        download.cancel(byProducingResumeData: { _ in })
                    }
                }
            }
        }
    }

    public func installXcode(from url: URL, skipSymlinkCreation: Bool, skipXcodeSelection: Bool, skipVerification: Bool = false) {
        list(updateList: true)
            .sink { xcodes in
                self.installXcode(from: url,
                                  knownXcodes: xcodes,
                                  skipSymlinkCreation: skipSymlinkCreation,
                                  skipXcodeSelection: skipXcodeSelection,
                                  skipVerification: skipVerification)
        }
        .store(in: &disposeBag)

        RunLoop.main.run()
    }

    private func installXcode(from url: URL, knownXcodes: [Xcode], skipSymlinkCreation: Bool, skipXcodeSelection: Bool, skipVerification: Bool = false) {
        self.logger.beginSection("Installing")

        if !skipVerification {
            let xcodeVerificationResult = self.verifyXcode(at: url)
            guard xcodeVerificationResult == EXIT_SUCCESS else {
                self.logger.error("Xcode verification failed.")
                try? FileManager.default.removeItem(at: url)
                fail(statusCode: xcodeVerificationResult)
            }
        }

        var passwordAttempts = 0
        let maxPasswordAttempts = 3
        var possiblePassword: String?
        repeat {
            passwordAttempts += 1
            self.logger.log("Prompting for password. Attempt \(passwordAttempts)!")
            let prompt: String = {
                if passwordAttempts == 1 {
                    return "Please enter your password:"
                } else {
                    return "Sorry, try again.\nPassword:"
                }
            }()
            possiblePassword = getPassword(prompt: prompt)
        } while possiblePassword == nil && passwordAttempts < maxPasswordAttempts

        guard let password = possiblePassword else {
            logger.error("Sorry, 3 incorrect password attempts")
            exit(EXIT_FAILURE)
        }

        enableDeveloperMode(password: password)
        approveLicense(password: password, url: url)
        installComponents(password: password, url: url)

        if !skipSymlinkCreation {
            createSymbolicLink(to: url, knownXcodes: knownXcodes)
        }

        if !skipXcodeSelection {
            selectXcode(at: url, password: password)
        }

        logger.log("Installed Xcode to \(url.path)")
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "/Applications")

        exit(EXIT_SUCCESS)
    }

    private func getPassword(prompt: String) -> String? {
        do {
            let password = try Shell.ask(prompt, secure: true) { pwd in
                logger.log("Verifying inserted password ...")
                let sudoExitStatus = Shell.executePrivileged(command: "ls", password: pwd, args: []).exitStatus
                logger.log("Success \(sudoExitStatus == EXIT_SUCCESS)")
                return sudoExitStatus == EXIT_SUCCESS
            }
            return password
        } catch {
            return nil
        }
    }

    @discardableResult public func selectXcode(at url: URL, password: String) -> Int {
        logger.log("Selecting Xcode...")
        let result = Shell.executePrivileged(command: "xcode-select", password: password, args: ["-s", url.path]).exitStatus
        logger.log("Selecting Xcode \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result)
    }

    private func createSymbolicLink(to destination: URL, knownXcodes: [Xcode]) {
        let symlinkURL = URL(fileURLWithPath: "/Applications/Xcode.app")
        let fileManager = FileManager.default

        if fileManager.isSymbolicLink(atPath: symlinkURL.path) {
            logger.verbose("Symbolic link at \(symlinkURL.path) found. Removing it...")
            try? fileManager.removeItem(at: symlinkURL)
        } else if fileManager.fileExists(atPath: symlinkURL.path) {
            logger.verbose("\(symlinkURL.path) already exists. Renaming it...")

            let installed = installedXcodes(knownVersions: knownXcodes)
            if let xcodeApp = installed.first(where: { $0.url == symlinkURL }) {
                logger.verbose("\(symlinkURL.path) already exists. Moving it to /Applications/\(xcodeApp.xcode.filename).", onSameLine: true)
                let destination = URL(fileURLWithPath: "/Applications/\(xcodeApp.xcode.filename)")
                try? fileManager.moveItem(at: symlinkURL, to: destination)
            }
        }

        logger.log("Creating symbolic link at \(symlinkURL.path).")
        try? fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: destination)
    }

    @discardableResult private func verifyXcode(at url: URL) -> Int {
        logger.log("Verifying Xcode...")
        let exitStatus = Shell.execute("/usr/bin/codesign", args: "--verify", "--verbose", url.path).exitStatus
        logger.log("Verifying Xcode \(exitStatus == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return exitStatus
    }

    @discardableResult public func enableDeveloperMode(password: String) -> Int {
        logger.log("Enabling Developer Mode...")

        let result1 = Shell.executePrivileged(command: "/usr/sbin/DevToolsSecurity", password: password, args: ["-enable"]).exitStatus

        guard result1 == EXIT_SUCCESS else {
            logger.log("Enabling Developer Mode ✗")
            return Int(result1)
        }

        let result2 = Shell.executePrivileged(command: "/usr/sbin/dseditgroup", password: password, args: "-o edit -t group -a staff _developer".components(separatedBy: " ")).exitStatus

        logger.log("Enabling Developer Mode \(result2 == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result2)
    }

    @discardableResult public func approveLicense(password: String, url: URL) -> Int {
        logger.log("Approving License...")
        let result = Shell.executePrivileged(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-license", "accept"]).exitStatus
        logger.log("Approving License \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
        return Int(result)
    }

    @discardableResult public func installComponents(password: String, url: URL) -> Int {
        logger.log("Install additional components...")
        let result = Shell.executePrivileged(command: "\(url.path)/Contents/Developer/usr/bin/xcodebuild", password: password, args: ["-runFirstLaunch"]).exitStatus
        logger.log("Install additional components \(result == EXIT_SUCCESS ? "✓" : "✗")", onSameLine: true)
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

        session.configuration.httpCookieStorage?.removeCookies(since: Date.distantPast)
        UserDefaults.standard.removeObject(forKey: "cookies")

        logger.log("Removed stored cookies.")
    }

    public func installedXcodes(updateList: Bool) {
        list(updateList: updateList)
            .sink { knownVersions in
                guard !knownVersions.isEmpty else {
                    self.logger.error("No Xcode releases found.")
                    exit(EXIT_FAILURE)
                }

                let xcodes = self.installedXcodes(knownVersions: knownVersions)
                let longestXcodeNameLength = xcodes.map { $0.xcode.description }.max(by: { $1.count > $0.count })!.count
                xcodes.forEach {
                    let displayVersion = $0.xcode.displayVersion
                    let attributedDisplayName = "\(displayVersion) (\($0.xcode.version.build ?? ""))"

                    let attributedName = attributedDisplayName.cyan
                    let width = longestXcodeNameLength + attributedName.count - attributedName.raw.count
                    self.logger.log("\(attributedName.paddedWithSpaces(to: width)) – \($0.url.path.cyan)")
                }

                exit(EXIT_SUCCESS)
            }.store(in: &disposeBag)

        RunLoop.main.run()
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
}
