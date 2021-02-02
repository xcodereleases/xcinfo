//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import IOKit
import IOKit.pwr_mgt
import OlympUs
import XCIFoundation

class FileDownload: NSObject, URLSessionDownloadDelegate {
    enum State {
        case downloading
        case finished
        case failed
    }

    public private(set) var objectDidChange = PassthroughSubject<Void, Never>()

    public let name: String

    private let task: URLSessionDownloadTask
    private let logger: Logger
    private var sleepAssertionID: IOPMAssertionID = 0

    public private(set) var state: State = .downloading
    public private(set) var progress: Double = 0
    public private(set) var downloadedURL: URL?
    private var startDate: Date!

    public private(set) var resumeData: Data?
    public private(set) var isCancelled = false

    private var totalBytesExpectedToWriteValue: Double = 0
    private var downloadSpeedValues = SpeedMeasurements()

    public var totalBytes: Measurement<UnitInformationStorage> {
        Measurement<UnitInformationStorage>(value: totalBytesExpectedToWriteValue, unit: .bytes)
    }

    public var remainingBytes: Measurement<UnitInformationStorage> {
        let bytesRemaining = max(0, totalBytesExpectedToWriteValue - totalBytesExpectedToWriteValue * progress)
        return Measurement<UnitInformationStorage>(value: bytesRemaining, unit: .bytes)
    }

    public func downloadSpeed() -> Measurement<UnitInformationStorage> {
        Measurement<UnitInformationStorage>(value: downloadSpeedValues.averageSpeed(), unit: .bytes)
    }

    init(task: URLSessionDownloadTask, delegateProxy: URLSessionDelegateProxy, logger: Logger, disableSleep: Bool = false) {
        name = task.originalRequest?.url?.absoluteString ?? task.currentRequest?.url?.absoluteString ?? "<unnnamed download>"
        self.task = task
        self.logger = logger
        super.init()

        if disableSleep {
            let reasonForActivity = "Preventing sleep during large file download"
            let success = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reasonForActivity as CFString,
                &sleepAssertionID
            )
            logger.verbose("Sleep temporary disabled: \(success == 0)")
        }
        delegateProxy.add(proxy: self)
        startDate = Date()
        task.resume()
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileName = (name as NSString).lastPathComponent
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: location, to: target)
            state = .finished
            progress = 1.0
            downloadedURL = target
        } catch {
            logger.error("Could not move temporary file from\n\(location)\nto\n\(target)")
            downloadedURL = nil
            state = .failed
        }
        notify()

        if sleepAssertionID != 0 {
            let success = IOPMAssertionRelease(sleepAssertionID)
            logger.verbose("Sleep enabled again: \(success == 0)")
        }
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        totalBytesExpectedToWriteValue = Double(totalBytesExpectedToWrite)
        downloadSpeedValues.append(Double(bytesWritten))
        notify()
    }

    private func notify() {
        objectDidChange.send()
    }

    func urlSession(_: URLSession, didBecomeInvalidWithError _: Error?) {
        state = .failed
        notify()
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as? URLError else {
            return
        }

        self.logger.error(error.localizedDescription)
        resumeData = error.downloadTaskResumeData
        isCancelled = error.code == .cancelled

        state = .failed
        notify()
    }
}

struct SpeedMeasurement {
    var value: Double
    let date: Date
}

struct SpeedMeasurements {
    private var buffer: [SpeedMeasurement]

    init() {
        buffer = []
    }

    mutating func append(_ value: Double) {
        let now = Date()
        while let first = buffer.first, now.timeIntervalSince(first.date) > 10 {
            buffer.remove(at: 0)
        }
        buffer.append(SpeedMeasurement(value: value, date: now))
    }

    func averageSpeed() -> Double {
        guard buffer.count > 1 else { return -1 }

        let deltaTime = buffer.last!.date.timeIntervalSince(buffer.first!.date)
        return buffer.reduce(0) { $0 + $1.value } / deltaTime
    }
}
