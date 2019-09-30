//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import XCUFoundation
import XCUnxip

class Extractor {
    enum State {
        case pending
        case extracting
        case finished
        case failed
    }

    public private(set) var appFilename: String
    public private(set) var objectDidChange = PassthroughSubject<Void, Never>()

    public private(set) var state: State = .pending { didSet { objectDidChange.send() } }
    public private(set) var progress: Double = 0 { didSet { objectDidChange.send() } }

    private let logger: Logger
    private let container: PKSignedContainer

    init?(forReadingFromContainerAt url: URL, appFilename: String, logger: Logger) {
        self.appFilename = appFilename
        do {
            container = try PKSignedContainer(forReadingFromContainerAt: url)
            self.logger = logger
        } catch {
            logger.error("Could not extract archive: \(error)")
            return nil
        }
    }

    func start() -> Future<URL, XCAPIError> {
        var previouslyDisplayedNonANSIProgress = -1

        return Future { promise in
            self.state = .extracting
            let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
            if self.logger.isVerbose {
                self.logger.verbose("Extracting xip to \(target)")
            } else {
                self.logger.log("Extracting ...")
            }
            var progressDisplay = ProgressDisplay(ratio: 0, width: 20)
            self.container.startUnarchiving(atPath: target, notifyOn: .main, progress: { progress, statusMessage in
                let ratio = progress / 100
                switch ratio {
                case _ where ratio < 0:
                    self.logger.log(statusMessage)
                case _ where ratio > 1:
                    self.logger.log("Probably done: \(statusMessage)")
                default:
                    progressDisplay.ratio = ratio
                    if self.logger.useANSI {
                        self.logger.log("\(progressDisplay.representation)", onSameLine: true)
                    } else {
                        if Int(progress).isMultiple(of: 5), previouslyDisplayedNonANSIProgress != Int(progress) {
                            self.logger.log("\(statusMessage): \(Int(progress))%")
                            previouslyDisplayedNonANSIProgress = Int(progress)
                        }
                    }
                }
                self.progress = ratio
            }) { _ in
                self.state = .finished
                if self.moveToApplicationsFolder(tempFolder: URL(fileURLWithPath: target)) {
                    self.logger.success("Done extracting: \(target)")
                    let applicationURL = URL(fileURLWithPath: "/Applications/\(self.appFilename)")
                    promise(.success(applicationURL))
                } else {
                    promise(.failure(.couldNotMoveToApplicationsFolder))
                }
            }
        }
    }

    private func moveToApplicationsFolder(tempFolder: URL) -> Bool {
        let fileManager = FileManager.default

        var sourceURL: URL = tempFolder.appendingPathComponent("Xcode.app")
        if !fileManager.fileExists(atPath: sourceURL.path) {
            sourceURL = tempFolder.appendingPathComponent("Xcode-beta.app")
            if !fileManager.fileExists(atPath: sourceURL.path) {
                return false
            }
        }

        let targetURL = URL(fileURLWithPath: "/Applications/\(appFilename)")
        logger.verbose("Moving application to \(targetURL.path)")
        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            return true
        } catch {
            logger.error("Moving application failed. Error: \(error.localizedDescription)")
            return false
        }
    }
}
