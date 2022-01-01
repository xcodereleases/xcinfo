//
//  File.swift
//  
//
//  Created by Kevin Guo on 2022/1/1.
//

import Foundation
import OlympUs
import Combine
import XCIFoundation

/// Holds a weak reverence
class Weak<T: AnyObject> {
    weak var value: T?

    init(value: T) {
        self.value = value
    }
}

//enum DownloadError: Error {
//  case missingData
//}

enum FileCacheError: Error {
    case sizeNotAvailableForRemoteResource
}

/// Represents the download of one part of the file
fileprivate class DownloadTask {
    /// The position (included) of the first byte
    let startOffset: Int64
    /// The position (not included) of the last byte
    let endOffset: Int64
    /// The byte length of the part
    var size: Int64 {
        return endOffset - startOffset
    }
    /// The number of bytes currently written
    var bytesWritten: Int64 = 0
    /// The URL task corresponding to the download
    let request: URLSessionDownloadTask
    /// The disk location of the saved file
    var didWriteTo: URL?

    init(for url: URL, from start: Int64, to end: Int64, in session: URLSession) {
        startOffset = start
        endOffset = end

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields?["Range"] = "bytes=\(start)-\(end - 1)"
        request.allHTTPHeaderFields?["Accept-Encoding"] = "gzip, deflate, br"
        request.allHTTPHeaderFields?["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"


        self.request = session.downloadTask(with: request)
    }
}

/// Represents the download of a file (that is done in multi parts)
class MultiPartsDownloadTask: NSObject, XCFileDownloadProtocol {

    public private(set) var objectDidChange = PassthroughSubject<Void, Never>()

    public private(set) var state: State = .downloading
    public private(set) var downloadedURL: URL?

    public private(set) var resumeData: Data?
    public private(set) var isCancelled = false

    private var totalBytesExpectedToWriteValue: Double = 0
    private var downloadSpeedValues = SpeedMeasurements()
    private var concurrent: Int

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


    /// the current progress, from 0 to 1
    var progress: Double {
        var total: Int64 = 0
        var written: Int64 = 0
        parts.forEach({ part in
            total += part.size
            written += part.bytesWritten
        })
        guard total > 0 else {
            return 0
        }
        return Double(written) / Double(total)
    }

    fileprivate var parts = [DownloadTask]()
    fileprivate var contentLength: Int64?
    fileprivate let url: URL
    private var session: URLSession
    private var isStopped = false
    private var isResumed = false
    /// When the download started
    private var startedAt: Date
    /// An estimate on how long left before the download is over
    var remainingTimeEstimate: CGFloat {
        let progress = self.progress
        guard progress > 0 else {
            return CGFloat.greatestFiniteMagnitude
        }
        return CGFloat(Date().timeIntervalSince(startedAt)) / progress * (1 - progress)
    }

    init(from url: URL, in session: URLSession, concurrent: Int, delegateProxy: URLSessionDelegateProxy, logger: Logger, disableSleep: Bool = false) {
        self.url = url
        self.session = session
        self.startedAt = Date()
        self.concurrent = concurrent

        super.init()
        delegateProxy.add(proxy: self)

        getRemoteResourceSize() { [weak self] (size, error) -> Void in
            guard let wself = self else {
                return
            }
            if let size = size {
                wself.contentLength = size
                wself.totalBytesExpectedToWriteValue = Double(size)
                wself.createDownloadParts()

                if !wself.isResumed {
                    wself.resume()
                }
            } else {
                wself.isStopped = true
            }
        }
    }

    /// Start the download
    func resume() {
        guard !isStopped else {
            return
        }
        startedAt = Date()
        isResumed = true
        parts.forEach({ $0.request.resume() })
    }

    /// Cancels the download
    func cancel() {
        guard !isStopped else {
            return
        }
        parts.forEach({ $0.request.cancel() })
    }

    /// Fetch the file size of a remote resource
    private func getRemoteResourceSize(completion: @escaping (Int64?, Error?) -> Void) {
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        session.dataTask(with: headRequest, completionHandler: { (data, response, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let expectedContentLength = response?.expectedContentLength else {
                completion(nil, FileCacheError.sizeNotAvailableForRemoteResource)
                return
            }
            completion(expectedContentLength, nil)
        }).resume()
    }

    /// Split the download request into multiple request to use more bandwidth
    private func createDownloadParts() {
        guard let size = contentLength else {
            return
        }

        let numberOfRequests = self.concurrent
        for i in 0..<numberOfRequests {
            let start = Int64(ceil(CGFloat(Int64(i) * size) / CGFloat(numberOfRequests)))
            let end = Int64(ceil(CGFloat(Int64(i + 1) * size) / CGFloat(numberOfRequests)))
            parts.append(DownloadTask(for: url, from: start, to: end, in: session))
        }
    }

    fileprivate func didFail(_ error: Error) {
        cancel()
        state = .failed
        notify()
    }

    fileprivate func didFinishOnePart() {
        if parts.filter({ $0.didWriteTo != nil }).count == parts.count {
            do {
                let url = try mergeFiles()
                state = .finished
//                progress = 1.0
                downloadedURL = url
            }
            catch {
                downloadedURL = nil
                state = .failed
            }
            notify()
        }
    }

    /// Put together the download files
    private func mergeFiles() throws -> URL {
        let ext = self.url.pathExtension
        let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

        let partLocations = parts.compactMap({ $0.didWriteTo })
        try FileManager.default.merge(files: partLocations, to: destination)
        for partLocation in partLocations {
            try FileManager.default.removeItem(at: partLocation)
        }
        return destination
    }

    private func notify() {
        objectDidChange.send()
    }
}

extension MultiPartsDownloadTask: URLSessionDownloadDelegate {
    public func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
    ) {
        guard let x = parts.first(where: { $0.request == downloadTask}) else {
            return
        }

        x.bytesWritten = totalBytesWritten
        downloadSpeedValues.append(Double(bytesWritten))
        notify()
    }

    func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
    ) {
        guard let x = parts.first(where: { $0.request == downloadTask}) else {
            return
        }

        let ext = self.url.pathExtension
        let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            self.didFail(error)
            return
        }

        x.didWriteTo = destination
        self.didFinishOnePart()
    }

    func urlSession(_: URLSession, didBecomeInvalidWithError _: Error?) {
        state = .failed
        notify()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as? URLError else {
            return
        }
        isCancelled = error.code == .cancelled
        self.didFail(error)
    }
}

extension FileManager {
    /// Merge the files into one (without deleting the files)
    func merge(files: [URL], to destination: URL, chunkSize: Int = 1000000) throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        let writer = try FileHandle(forWritingTo: destination)
        try files.forEach({ partLocation in
            let reader = try FileHandle(forReadingFrom: partLocation)
            var data = reader.readData(ofLength: chunkSize)
            while data.count > 0 {
                writer.write(data)
                data = reader.readData(ofLength: chunkSize)
            }
            reader.closeFile()
        })
        writer.closeFile()
    }
}
