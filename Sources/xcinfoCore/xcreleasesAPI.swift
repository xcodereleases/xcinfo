//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
import Combine
import Foundation
import XCIFoundation

public struct XcodeReleaseLink: Codable {
    public var url: URL
}

public struct XcodeReleaseLinkCollection: Codable {
    public var notes: XcodeReleaseLink?
    public var download: XcodeReleaseLink?
}

public struct XcodeReleaseVersion: Codable {
    public var number: String
    public var build: String
    public var release: XcodeReleaseInfo
}

public struct SDKReleaseVersion: Codable {
    public var number: String?
    public var build: String
    public var release: XcodeReleaseInfo
}

public struct CompilerReleaseVersion: Codable {
    public var number: String?
    public var build: String
    public var release: XcodeReleaseInfo
}

public struct XcodeReleaseInfo {
    public var gm: Bool = true
    public var gmSeed: Int?
    public var beta: Int?
    public var dp: Int?
}

extension XcodeReleaseInfo: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gm = try container.decodeIfPresent(Bool.self, forKey: .gm) ?? false
        gmSeed = try container.decodeIfPresent(Int.self, forKey: .gmSeed)
        beta = try container.decodeIfPresent(Int.self, forKey: .beta)
        dp = try container.decodeIfPresent(Int.self, forKey: .dp)
    }
}

public enum Platform: String, Codable {
    case macOS
    case iOS
    case tvOS
    case watchOS
}

public struct XcodeRelease: Codable {
    public var links: XcodeReleaseLinkCollection?
    public var name: String
    public var version: XcodeReleaseVersion
    public var requires: String
    public var date: XcodeReleaseDate
    public var sdks: [String: [SDKReleaseVersion]]?
    public var compilers: [String: [CompilerReleaseVersion]]?
}

public struct XcodeReleaseDate: Codable {
    public var year: Int
    public var month: Int
    public var day: Int
}

public struct XcodeApplication {
    public var url: URL
    public var release: XcodeRelease
}

extension XcodeApplication: Comparable {
    public static func < (lhs: XcodeApplication, rhs: XcodeApplication) -> Bool {
        lhs.release < rhs.release
    }
}

extension XcodeRelease {
    public var releaseDate: Date {
        Calendar.current.date(from: DateComponents(year: date.year,
                                                   month: date.month,
                                                   day: date.day)) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

extension XcodeRelease: CustomStringConvertible, CustomDebugStringConvertible {
    var displayVersion: String {
        var components: [String] = [version.number]
        if let gmSeed = version.release.gmSeed {
            components.append("GM Seed \(gmSeed)")
        } else if let betaVersion = version.release.beta {
            components.append("Beta \(betaVersion)")
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

    var attributedDisplayVersion: String {
        var components: [String] = [version.number]
        if let gmSeed = version.release.gmSeed {
            components.append("GM Seed \(gmSeed)")
        } else if let betaVersion = version.release.beta {
            components.append("Beta \(betaVersion)")
        }
        return components.joined(separator: " ").f.Cyan
    }

    public var attributedDisplayName: String { "\(attributedDisplayVersion) (\(version.build))" }
}

extension XcodeRelease {
    var isBeta: Bool {
        version.isBeta
    }
}

extension XcodeReleaseVersion {
    var isGM: Bool {
        release.gm || release.gmSeed != nil
    }

    var isBeta: Bool {
        !isGM && (release.beta != nil || release.dp != nil)
    }
}

extension XcodeRelease: Comparable, Hashable {
    public static func == (lhs: XcodeRelease, rhs: XcodeRelease) -> Bool {
        lhs.version == rhs.version
    }

    public static func < (lhs: XcodeRelease, rhs: XcodeRelease) -> Bool {
        lhs.version < rhs.version
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
    }
}

extension XcodeReleaseVersion: Comparable, Hashable {
    public static func < (lhs: XcodeReleaseVersion, rhs: XcodeReleaseVersion) -> Bool {
        let numberComparision = lhs.number.compare(rhs.number, options: .numeric)

        if lhs.isGM, rhs.isGM {
            if numberComparision == .orderedSame {
                return lhs.build.compare(rhs.build, options: .numeric) == .orderedAscending
            } else {
                return numberComparision == .orderedAscending
            }
        } else if numberComparision == .orderedSame {
            if let lhsBeta = lhs.release.beta, let rhsBeta = rhs.release.beta {
                return lhsBeta < rhsBeta
            } else if lhs.isGM, rhs.isBeta {
                return false
            } else {
                return true
            }
        }
        return numberComparision == .orderedAscending
    }

    public static func == (lhs: XcodeReleaseVersion, rhs: XcodeReleaseVersion) -> Bool {
        lhs.number == rhs.number
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

enum XCAPIError: Error {
    case invalidResponse
    case invalidList
    case invalidCache
    case versionNotFound
    case downloadInterrupted
    case couldNotMoveToTemporaryFile
    case couldNotExtractFile
    case couldNotMoveToApplicationsFolder
    case unauthorized
}

class xcreleasesAPI {
    public let baseURL: URL
    private let logger: Logger
    private var disposeBag = Set<AnyCancellable>()

    init(baseURL: URL, logger: Logger) {
        self.baseURL = baseURL
        self.logger = logger
    }

    public func remoteList() -> Future<[XcodeRelease], XCAPIError> {
        Future { promise in
            let request = URLRequest(url: self.baseURL)
            URLSession.shared.dataTaskPublisher(for: request)
                .map { $0.data }
                .decode(type: [XcodeRelease].self, decoder: JSONDecoder())
                .handleEvents(receiveOutput: { values in
                    self.cacheListResponse(content: values)
                })
                .sink(receiveCompletion: { _ in
                    promise(.failure(.invalidResponse))
                }, receiveValue: { values in
                    promise(.success(values))
                })
                .store(in: &self.disposeBag)
        }
    }

    @discardableResult
    private func cacheListResponse(content: [XcodeRelease]) -> Bool {
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

    public func cachedList() -> Future<[XcodeRelease], XCAPIError> {
        Future { promise in
            guard let cacheFile = self.cacheFile else {
                promise(.failure(.invalidCache))
                return
            }
            do {
                let data = try Data(contentsOf: cacheFile)
                let result = try JSONDecoder().decode([XcodeRelease].self, from: data)
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
