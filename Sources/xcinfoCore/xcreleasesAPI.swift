//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
import Combine
import Foundation
import XCIFoundation
import XCModel

struct XcodeApplication {
    public var url: URL
    public var xcode: Xcode
}

extension XcodeApplication: Comparable {
    public static func < (lhs: XcodeApplication, rhs: XcodeApplication) -> Bool {
        lhs.xcode < rhs.xcode
    }
}

extension Xcode {
    public var releaseDate: Date {
        Calendar.current.date(from: DateComponents(year: date.year,
                                                   month: date.month,
                                                   day: date.day)) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

extension Xcode: CustomStringConvertible, CustomDebugStringConvertible {
    var displayVersion: String {
        var components: [String] = []
        if let number = version.number {
            components.append(number)
        }
        if case let .gmSeed(version) = version.release {
            components.append("GM Seed \(version)")
        } else if case let .beta(version) = version.release {
            components.append("Beta \(version)")
        } else if case let .dp(version) = version.release {
            components.append("DP \(version)")
        }
        return components.joined(separator: " ")
    }

    var displayName: String { "\(displayVersion) (\(version.build))" }

    var filename: String {
        let fileManager = FileManager.default
        var filename = "Xcode \(displayVersion).app"
        var counter = 1
        while fileManager.fileExists(atPath: "/Applications/\(filename)") {
            counter += 1
            filename = "Xcode \(displayVersion) - \(counter).app"
        }
        return filename
    }

    public var description: String { displayName }
    public var debugDescription: String { displayName }

    var attributedDisplayVersion: String { displayVersion.f.Cyan }

    public var attributedDisplayName: String { "\(attributedDisplayVersion) (\(version.build))" }
}

extension Xcode {
    var isBeta: Bool { version.isBeta }
}

extension Version {
    var isGM: Bool { release.isGM }

    var isGMSeed: Bool {
        guard case .gmSeed = release else { return false }
        return true
    }

    var isBeta: Bool {
        guard case .beta = release else { return false }
        return true
    }

    var isDP: Bool {
        guard case .dp = release else { return false }
        return true
    }
}

extension Xcode: Comparable, Hashable {
    public static func == (lhs: Xcode, rhs: Xcode) -> Bool {
        lhs.version == rhs.version
    }

    public static func < (lhs: Xcode, rhs: Xcode) -> Bool {
        lhs.version < rhs.version
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
    }
}

extension Version: Comparable, Hashable {
    public static func < (lhs: Version, rhs: Version) -> Bool {
        let numberComparision: ComparisonResult = {
            guard let lhsNumber = lhs.number, let rhsNumber = rhs.number else { return .orderedSame }
            return lhsNumber.compare(rhsNumber, options: .numeric)
        }()

        if lhs.isGM, rhs.isGM {
            if numberComparision == .orderedSame {
                return lhs.build.compare(rhs.build, options: .numeric) == .orderedAscending
            } else {
                return numberComparision == .orderedAscending
            }
        } else if numberComparision == .orderedSame {
            switch (lhs.release, rhs.release) {
            case let (.gmSeed(lhsVersion), .gmSeed(rhsVersion)):
                return lhsVersion < rhsVersion
            case let (.beta(lhsVersion), .beta(rhsVersion)):
                return lhsVersion < rhsVersion
            case let (.dp(lhsVersion), .dp(rhsVersion)):
                return lhsVersion < rhsVersion
            default:
                return false
            }
        }
        return numberComparision == .orderedAscending
    }

    public static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.number == rhs.number
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

protocol KeyedVersions {}
extension KeyedVersions {
    func keyed() -> [String: [Version]] {
        let mirror = Mirror(reflecting: self)
        var dict: [String: [Version]] = [:]
        for child in mirror.children {
            guard let key = child.label, let versions = child.value as? [Version] else { continue }
            dict[key] = versions
        }
        return dict
    }
}
extension SDKs: KeyedVersions {}
extension Compilers: KeyedVersions {}

enum XCAPIError: Error, CustomStringConvertible {
    case invalidResponse
    case invalidCache
    case versionNotFound
    case downloadInterrupted
    case couldNotMoveToTemporaryFile
    case couldNotMoveToApplicationsFolder
    case timeout

    var description: String {
        switch self {
        case .invalidResponse:
            return "invalid response"
        case .invalidCache:
            return "invalid cache file"
        case .versionNotFound:
            return "version not found"
        case .downloadInterrupted:
            return "download was interrupted"
        case .couldNotMoveToTemporaryFile:
            return "could not move downloaded file into temporary directory"
        case .couldNotMoveToApplicationsFolder:
            return "application could not be moved into /Applications"
        case .timeout:
            return "the request timed out"
        }
    }
}

class xcreleasesAPI {
    public let baseURL: URL
    private let logger: Logger
    private var disposeBag = Set<AnyCancellable>()
    private let session: URLSession

    init(baseURL: URL, logger: Logger, session: URLSession) {
        self.baseURL = baseURL
        self.logger = logger
        self.session = session
    }

    public func remoteList() -> Future<[Xcode], XCAPIError> {
        Future { [unowned session] promise in
            let request = URLRequest(url: self.baseURL)
            session.dataTaskPublisher(for: request)
                .map { $0.data }
                .decode(type: [Xcode].self, decoder: JSONDecoder())
                .handleEvents(receiveOutput: { values in
                    self.cacheListResponse(content: values)
                })
                .sink(receiveCompletion: { completion in
                    guard case let .failure(error) = completion else { return }
                    if (error as NSError).code == NSURLErrorTimedOut {
                        promise(.failure(.timeout))
                    } else {
                        promise(.failure(.invalidResponse))
                    }
                }, receiveValue: { values in
                    promise(.success(values))
                })
                .store(in: &self.disposeBag)
        }
    }

    @discardableResult
    private func cacheListResponse(content: [Xcode]) -> Bool {
        guard let cacheFile = cacheFile else {
            return false
        }
        do {
            let data = try JSONEncoder().encode(content)
            try data.write(to: cacheFile)
            return true
        } catch {
            return false
        }
    }

    private var cacheDirectory: URL? {
        guard
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            return nil
        }
        let directory = cachesDirectory.appendingPathComponent("xcinfo")
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: false,
                    attributes: nil
                )

            } catch {
                return nil
            }
        }
        return directory
    }

    private var cacheFile: URL? {
        cacheDirectory?.appendingPathComponent("xcinfo.json")
    }

    public func cachedList() -> Future<[Xcode], XCAPIError> {
        Future { promise in
            guard let cacheFile = self.cacheFile else {
                promise(.failure(.invalidCache))
                return
            }
            do {
                let data = try Data(contentsOf: cacheFile)
                let result = try JSONDecoder().decode([Xcode].self, from: data)
                promise(.success(result))
            } catch {
                promise(.failure(.invalidCache))
            }
        }
    }
}

extension OperatingSystemVersion {
    init?(string: String) {
        var components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        if components.count == 2 {
            components.append(0)
        }
        self.init(majorVersion: components[0], minorVersion: components[1], patchVersion: components[2])
    }

    var versionString: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
}
