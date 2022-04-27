//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import OlympUs
import XCIFoundation

public struct Environment {
    public var logger: Logger
    public var api: APIClient
    public var cachesDirectory: URL
    public var credentialProviding: CredentialProviding
    public var authenticationProviding: AuthenticationProviding
    public var downloadProviding: DownloadProviding
}

public extension Environment {
    static func live(isVerboseLoggingEnabled: Bool = false) -> Self {
        let logger = Logger(isVerbose: isVerboseLoggingEnabled)
        let credentialsService = CredentialService(logger: logger)

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = .shared
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config, delegate: sessionDelegateProxy, delegateQueue: nil)
        let xcReleasesAPI = XCReleasesAPI(
            baseURL: URL(string: "https://xcodereleases.com/data.json")!,
            session: session
        )

        let olymp = OlympUs(logger: logger, session: session)
        let downloader = Downloader(logger: logger, olymp: olymp, sessionDelegateProxy: sessionDelegateProxy)
        let authenticator = AppleAuthenticator(olymp: olymp, logger: logger)

        return .init(
            logger: logger,
            api: xcReleasesAPI.apiClient,
            cachesDirectory: FileManager.default.cachesDirectory,
            credentialProviding: credentialsService.credentialProviding,
            authenticationProviding: authenticator.authenticationProviding,
            downloadProviding: downloader.downloadProviding
        )
    }
}

private let xcReleasesAPI: XCReleasesAPI = {
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieAcceptPolicy = .always
    config.httpCookieStorage = .shared
    config.timeoutIntervalForRequest = 5
    let session = URLSession(configuration: config, delegate: sessionDelegateProxy, delegateQueue: nil)
    return XCReleasesAPI(baseURL: URL(string: "https://xcodereleases.com/data.json")!, session: session)
}()

private let sessionDelegateProxy = URLSessionDelegateProxy()

extension FileManager {
    var cachesDirectory: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = cachesDirectory.appendingPathComponent("xcinfo")
        try! FileManager.default.ensureFolderExists(directory)
        return directory
    }

    func ensureFolderExists(_ folder: URL) throws {
        if !fileExists(atPath: folder.path) {
            try createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
}
