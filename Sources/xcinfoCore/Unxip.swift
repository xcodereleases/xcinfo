//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

// Many thanks to Saagar Jha: https://github.com/saagarjha/unxip

import Foundation
import libunxip
import XCIFoundation

struct Unxip {
    let input: URL
    let output: URL
    let logger: Logger

    private let statistics: Statistics

    init(input: URL, output: URL, logger: Logger) {
        self.input = input
        self.output = output
        self.logger = logger
        self.statistics = Statistics()
    }

    func extract(progress: ((Double) -> Void)?) async throws {
        await statistics.setProgressHandler(progress)
        let handle = try FileHandle(forReadingFrom: input)
        try handle.seekToEnd()
        try await statistics.setTotal(Int64(handle.offset()))
        try handle.seek(toOffset: 0)

        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        guard fileManager.changeCurrentDirectoryPath(output.path()) else {
            throw CoreError.invalidExtractionOutputURL(output)
        }

        let file = AsyncThrowingStream(erasing: DataReader.data(readingFrom: handle.fileDescriptor))
        let (data, input) = file.lockstepSplit()

        Task {
            for try await data in data {
                await statistics.noteRead(size: data.count)
            }
        }

        for try await file in libunxip.Unxip.makeStream(
            from: .xip(wrapping: input),
            to: .disk,
            input: DataReader(data: input),
            nil,
            nil,
            .init(compress: true, dryRun: false)
        ) {
            logger.verbose("Extracted: \(file.name)")
        }

        fileManager.changeCurrentDirectoryPath(currentDir)
    }
}

private actor Statistics {
    // There seems to be a compiler bug where this needs to be outside of init
    static func start() -> ContinuousClock.Instant? {
        ContinuousClock.now
    }

    var start: ContinuousClock.Instant?
    var files = 0
    var directories = 0
    var symlinks = 0
    var hardlinks = 0
    var read: Int64 = 0
    var total: Int64?
    var identifiers = Set<FileIdentifier>()
    var progressHandler: ((Double) -> Void)?

    let source: DispatchSourceSignal

    init() {
        start = Self.start()

        let watchedSignal: CInt
        watchedSignal = SIGINFO

        let source = DispatchSource.makeSignalSource(signal: watchedSignal)
        self.source = source
        source.resume()
    }

    func setProgressHandler(_ handler: ((Double) -> Void)?) {
        progressHandler = handler
    }

    func noteRead(size bytes: Int) {
        read += Int64(bytes)
        if let total {
            progressHandler?(Double(read) / Double(total))
        }
    }

    func setTotal(_ total: Int64) {
        self.total = total
    }
}

private struct FileIdentifier: Hashable {
    let dev: Int
    let ino: Int
}

private extension File {
    var identifier: FileIdentifier {
        FileIdentifier(dev: dev, ino: ino)
    }
}

extension AsyncThrowingStream where Failure == Error {
    init<S: AsyncSequence>(erasing sequence: S) where S.Element == Element {
        var iterator = sequence.makeAsyncIterator()
        self.init {
            try await iterator.next()
        }
    }
}
