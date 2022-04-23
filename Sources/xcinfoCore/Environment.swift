//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import OlympUs

public struct Environment {
    public var log: (String) -> Void
    public var api: APIClient
    public var cachesDirectory: URL
}

public extension Environment {
    static let live: Self = .init(
        log: { print($0) },
        api: xcReleasesAPI.apiClient,
        cachesDirectory: FileManager.default.cachesDirectory
    )
}

fileprivate let xcReleasesAPI: XCReleasesAPI = {
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieAcceptPolicy = .always
    config.httpCookieStorage = .shared
    config.timeoutIntervalForRequest = 5
    let session = URLSession(configuration: config, delegate: sessionDelegateProxy, delegateQueue: nil)
    return XCReleasesAPI(baseURL: URL(string: "https://xcodereleases.com/data.json")!, session: session)
}()

fileprivate let sessionDelegateProxy = URLSessionDelegateProxy()

extension FileManager {
    var cachesDirectory: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = cachesDirectory.appendingPathComponent("xcinfo")
        try! FileManager.default.ensureFolderExists(directory)
        return directory
    }

    func ensureFolderExists(_ folder: URL) throws {
        if fileExists(atPath: folder.path) {
            try createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
}
