//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import XCIFoundation
import XCUnxip
import Rainbow

class Extractor {
    struct ExtractionError: Error {
        var underlyingError: Error
    }

    enum State {
        case pending
        case extracting
        case finished
        case failed
    }

    let source: URL
    let destination: URL
    let appFilename: String?
    let objectDidChange = PassthroughSubject<Void, Never>()

    private var state: State = .pending { didSet { objectDidChange.send() } }
    private var progress: Double = 0 { didSet { objectDidChange.send() } }

    private let logger: Logger
    private var container: PKSignedContainer!

    init(forReadingFromContainerAt url: URL, destination: URL, appFilename: String?, logger: Logger) {
        self.source = url
        self.destination = destination
        self.appFilename = appFilename
        self.logger = logger
    }

    func extract() async throws -> URL {
        try await start().singleOutput()
    }

    func extractExperimental() async throws -> URL {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.ensureFolderExists(target)

        try await Unxip(options: .init(input: source, output: target)).extract()
        self.logger.success("Done extracting: \(target.path)")

        if let applicationURL = self.moveToDestinationFolder(tempFolder: target) {
            return applicationURL
        } else {
            throw ExtractionError(underlyingError: XCAPIError.couldNotMoveToApplicationsFolder)
        }
    }

    func start() -> Future<URL, Error> {
        var previouslyDisplayedNonANSIProgress = -1

        return Future { promise in
            do {
                self.container = try PKSignedContainer(forReadingFromContainerAt: self.source)
            } catch {
                promise(.failure(ExtractionError(underlyingError: error)))
            }

            self.state = .extracting
            let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            self.logger.verbose("Extracting xip to \(target.path)")

            var progressDisplay = ProgressDisplay(ratio: 0, width: 20)
            self.container.startUnarchiving(atPath: target.path, notifyOn: .main, progress: { progress, statusMessage in
                let ratio = progress / 100
                switch ratio {
                case _ where ratio < 0:
                    self.logger.log(statusMessage)
                case _ where ratio > 1:
                    self.logger.log("Probably done: \(statusMessage)")
                default:
                    progressDisplay.ratio = ratio
                    if Rainbow.enabled {
                        self.logger.log("\(progressDisplay.representation)", onSameLine: true)
                    } else {
                        if Int(progress).isMultiple(of: 5), previouslyDisplayedNonANSIProgress != Int(progress) {
                            self.logger.log("\(statusMessage.isEmpty ? "Done" : statusMessage): \(Int(progress)) %")
                            previouslyDisplayedNonANSIProgress = Int(progress)
                        }
                    }
                }
                self.progress = ratio
            }) { _ in
                self.logger.success("Done extracting: \(target.path)")
                if let applicationURL = self.moveToDestinationFolder(tempFolder: target) {
                    self.state = .finished
                    promise(.success(applicationURL))
                } else {
                    self.state = .failed
                    promise(.failure(XCAPIError.couldNotMoveToApplicationsFolder))
                }
            }
        }
    }

    private func moveToDestinationFolder(tempFolder: URL) -> URL? {
        let fileManager = FileManager.default

        let appName: String
        var sourceURL: URL = tempFolder.appendingPathComponent("Xcode.app")
        if !fileManager.fileExists(atPath: sourceURL.path) {
            sourceURL = tempFolder.appendingPathComponent("Xcode-beta.app")
            appName = appFilename ?? "Xcode-beta.app"
            if !fileManager.fileExists(atPath: sourceURL.path) {
                return nil
            }
        } else {
            appName = appFilename ?? "Xcode.app"
        }

        let targetURL = destination.appendingPathComponent(appName)
        logger.verbose("Moving application to \(targetURL.path)")
        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            return targetURL
        } catch {
            logger.error("Moving application failed. Error: \(error.localizedDescription)")
            return nil
        }
    }
}
