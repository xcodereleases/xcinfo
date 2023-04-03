@testable import xcinfoCore
import XCModel
import XCTest
import CustomDump

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
        let versions: [String: VersionParts] = [
            "14": VersionParts(major: 14),
            "14.3": VersionParts(major: 14, minor: 3),
            "14.3 RC 2": VersionParts(major: 14, minor: 3, type: .rc("2")),
            "14.0.1": VersionParts(major: 14, minor: 0, patch: 1),
            "11.6 GM": VersionParts(major: 11, minor: 6, type: .gm("")),
            "11.3.1 GM": VersionParts(major: 11, minor: 3, patch: 1, type: .gm("")),
            "11.2.1 GM Seed 1": VersionParts(major: 11, minor: 2, patch: 1, type: .gm("Seed 1")),
            "8.3 Beta 3": VersionParts(major: 8, minor: 3, type: .beta("3")),
            "5.1 DP 2": VersionParts(major: 5, minor: 1, type: .dp("2")),
        ]

        for (versionString, expected) in versions {
            let parts = VersionParts(rawValue: versionString)
            XCTAssertNoDifference(expected, parts, "Failed for \(versionString)")
        }
    }
}
