//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import OlympUs
import Rainbow
import XCIFoundation

enum DownloadError: Error {
    case listUpdateError
}

public struct DownloadProviding {
    var download: (URL, URL, Bool) async throws -> URL
    var cleanup: () -> Void
}

class Downloader {
    private var disposeBag = Set<AnyCancellable>()
    private let unauthorizedURL = URL(string: "https://developer.apple.com/unauthorized/")!
    private let logger: Logger
    private let olymp: OlympUs
    private let sessionDelegateProxy: URLSessionDelegateProxy

    init(logger: Logger, olymp: OlympUs, sessionDelegateProxy: URLSessionDelegateProxy) {
        self.logger = logger
        self.olymp = olymp
        self.sessionDelegateProxy = sessionDelegateProxy
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "jms", options: 0, locale: nil)
        return formatter
    }()

    public func start(url: URL, disableSleep: Bool, resumeData: Data? = nil) -> Future<URL, XCAPIError> {
        var progressDisplay = ProgressDisplay(ratio: 0, width: 20)
        let start = Date()

        return Future { promise in
            let task: URLSessionDownloadTask
            if let resumeData = resumeData {
                task = self.olymp.session.downloadTask(withResumeData: resumeData)
            } else {
                var request = URLRequest(url: url)
                request.addValue(
                    "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    forHTTPHeaderField: "Accept"
                )
                request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

                task = self.olymp.session.downloadTask(with: request)
            }

            let download = FileDownload(
                task: task,
                delegateProxy: self.sessionDelegateProxy,
                logger: self.logger,
                disableSleep: disableSleep
            )

            if resumeData == nil {
                self.logger.verbose("[\(Self.dateFormatter.string(from: Date()))] Starting download")
            } else {
                self.logger.verbose("[\(Self.dateFormatter.string(from: Date()))] Resuming download")
            }

            self.logger.log("Source: \(url)")
            var hasLoggedTotalSize = false
            var previouslyDisplayedNonANSIProgress = -1

            download.objectDidChange
                .throttle(for: 1, scheduler: RunLoop.main, latest: true)
                .sink {
                    switch download.state {
                    case .downloading:
                        if !hasLoggedTotalSize {
                            self.logger.log(
                                "Source: \(url) (\(Self.byteCountFormatter.string(from: download.totalBytes)))\n",
                                onSameLine: true
                            )
                            hasLoggedTotalSize = true
                        }
                        if Rainbow.enabled {
                            progressDisplay.ratio = download.progress
                            let logMessage = [
                                progressDisplay.representation,
                                "remaining: \(Self.byteCountFormatter.string(from: download.remainingBytes))",
                                "speed: \(Self.byteCountFormatter.string(from: download.downloadSpeed()))/s"
                            ].joined(separator: ", ")
                            self.logger.log(logMessage, onSameLine: true)
                        } else {
                            let progress = Int(100 * download.progress)
                            print(String(format: "%.1f %", 100 * download.progress))
                            if progress.isMultiple(of: 5), previouslyDisplayedNonANSIProgress != progress {
                                self.logger.log("Download progress: \(progress) %")
                                previouslyDisplayedNonANSIProgress = progress
                            }
                        }
                    case .finished:
                        let downloadTime = Date().timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
                        if Rainbow.enabled {
                            progressDisplay.ratio = 1
                            let formatter = DateComponentsFormatter()
                            formatter.unitsStyle = .abbreviated
                            formatter.allowedUnits = [.hour, .minute, .second]
                            let logMessage = [
                                progressDisplay.representation,
                                "Download time: \(formatter.string(from: downloadTime) ?? "???")"
                            ].joined(separator: ", ")
                            self.logger.log(logMessage, onSameLine: true)
                        } else {
                            self.logger.log("Download progress: 100 %")
                        }

                        self.sessionDelegateProxy.remove(proxy: download)

                        guard let downloadedURL = download.downloadedURL else {
                            promise(.failure(.couldNotMoveToTemporaryFile))
                            return
                        }
                        promise(.success(downloadedURL))
                    case .failed:
                        self.sessionDelegateProxy.remove(proxy: download)

                        switch (download.downloadedURL, download.resumeData) {
                        case let (nil, resumeData?) where download.isCancelled:
                            self.saveResumeData(resumeData, for: url)
                            promise(.failure(.downloadInterrupted))
                        case let (nil, resumeData?):
                            promise(.failure(.recoverableDownloadError(url: url, resumeData: resumeData)))
                        case (nil, nil):
                            promise(.failure(.couldNotMoveToTemporaryFile))
                        case (.some, _):
                            promise(.failure(.downloadInterrupted))
                        }
                    }
                }
                .store(in: &self.disposeBag)
        }
    }

    public func cacheURL(for url: URL) -> URL? {
        guard
            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("xcinfo")
        else {
            logger.error("Unable to save unfinished download")
            return nil
        }

        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: false, attributes: nil)

        let fileName = url.appendingPathExtension("resume").lastPathComponent
        return cache.appendingPathComponent(fileName)
    }

    private func saveResumeData(_ resumeData: Data, for url: URL) {
        guard let targetURL = cacheURL(for: url) else {
            logger.error("Unable to save unfinished download")
            return
        }

        do {
            try resumeData.write(to: targetURL)
        } catch {
            logger.error("Unable to save unfinished download")
            logger.error(error.localizedDescription)
        }
    }

    public func removeCachedResumeData(for url: URL) {
        guard let cacheURL = cacheURL(for: url) else {
            return
        }

        try? FileManager.default.removeItem(at: cacheURL)
    }

    public func download(url: URL, destination: URL, disableSleep: Bool) async throws -> URL {
        try await download(url: url, destination: destination, disableSleep: disableSleep).singleOutput()
    }

    public func download(
        url: URL,
        destination: URL,
        disableSleep: Bool,
        resumeData: Data? = nil
    ) -> AnyPublisher<URL, XCAPIError> {
        let resumeData = resumeData ?? cacheURL(for: url).flatMap { try? Data(contentsOf: $0) }

        return start(url: url, disableSleep: disableSleep, resumeData: resumeData)
            .catch { error -> AnyPublisher<URL, XCAPIError> in
                guard case let XCAPIError.recoverableDownloadError(url, resumeData) = error else {
                    return Fail(error: error).eraseToAnyPublisher()
                }

                let foo = Just(())
                    .setFailureType(to: XCAPIError.self)
                    .delay(for: .seconds(3), scheduler: DispatchQueue.global())
                    .flatMap { [unowned self] in
                        download(url: url, destination: destination, disableSleep: disableSleep, resumeData: resumeData)
                    }
                    .eraseToAnyPublisher()
                return foo
            }
            .flatMap { tmpURL -> AnyPublisher<URL, XCAPIError> in
                let destFile = destination.appendingPathComponent(tmpURL.lastPathComponent)
                do {
                    try FileManager.default.ensureFolderExists(destination)
                    if tmpURL != destFile {
                        try FileManager.default.moveItem(at: tmpURL, to: destFile)
                    }
                    return Just(destFile)
                        .setFailureType(to: XCAPIError.self)
                        .eraseToAnyPublisher()
                } catch let error as NSError {
                    return Fail(error: XCAPIError.couldNotMoveToDestinationFolder(tmpURL, destFile, error))
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    public func cleanup() {
        olymp.cleanup()
    }
}

extension Downloader {
    var downloadProviding: DownloadProviding {
        .init(download: download, cleanup: cleanup)
    }
}
