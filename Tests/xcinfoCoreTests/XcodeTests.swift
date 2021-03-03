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
}
