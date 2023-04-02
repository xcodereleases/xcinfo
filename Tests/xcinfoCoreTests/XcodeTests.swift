@testable import xcinfoCore
import XCModel
import XCTest

final class XcodeTests: XCTestCase {

    func testFilename() throws {
        let xcode1 = Xcode(version: Version("12345", "12.5", .beta(5)), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12.5_beta_5.app", xcode1.filename)

        let xcode2 = Xcode(version: Version("12345", "12.4.1", .gm), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12.4.1_gm.app", xcode2.filename)

        let xcode3 = Xcode(version: Version("12345", "12.4", .release), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12.4.app", xcode3.filename)

        let xcode4 = Xcode(version: Version("12345", "12.4", .rc(1)), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12.4_rc_1.app", xcode4.filename)

        let xcode5 = Xcode(version: Version("12345", "12.3", .dp(6)), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12.3_dp_6.app", xcode5.filename)

        let xcode6 = Xcode(version: Version("12345", "12", .gmSeed(3)), date: (1, 3, 2021), requires: "FOO")
        XCTAssertEqual("Xcode_12_gmseed_3.app", xcode6.filename)
    }

    func testVersionParts() throws {
        let versions = [
            "14.3",
            "14.3 RC 2",
            "14.0.1",
            "11.6 GM",
            "11.3.1 GM",
            "11.2.1 GM Seed 1",
            "8.3 Beta 3",
            "5.1 DP 2",
        ]

        for versionString in versions {
            let parts = VersionParts(rawValue: versionString)
            XCTAssertEqual(versionString.expectedParts, parts)
        }
    }
}

extension String {
    var expectedParts: VersionParts? {
        let splitted = split(separator: " ")
        guard let versionParts = splitted.first?.split(separator: ".") else {
            return nil
        }
        guard let majorString = versionParts.first, let major = Int(majorString) else {
            return nil
        }
        let minor = versionParts[safe: 1].flatMap { Int($0) } ?? 0
        let patch = versionParts[safe: 2].flatMap { Int($0) }

        let remainingParts = splitted.dropFirst()
        let versionType: VersionParts.VersionType
        if let type = remainingParts.first {
            switch type.lowercased() {
            case "rc":
                versionType = .rc(remainingParts.dropFirst().joined(separator: " "))
            case "dp":
                versionType = .dp(remainingParts.dropFirst().joined(separator: " "))
            case "beta":
                versionType = .beta(remainingParts.dropFirst().joined(separator: " "))
            case "gm":
                versionType = .gm(remainingParts.dropFirst().joined(separator: " "))
            default:
                fatalError()
            }
        } else {
            versionType = .release
        }


        return .init(major: major, minor: minor, patch: patch, type: versionType)
    }
}
