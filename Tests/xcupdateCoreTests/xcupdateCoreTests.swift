//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import XCTest
@testable import xcupdateCore

final class xcupdateCoreTests: XCTestCase {
    func testVersionComparision() {
        let first = XcodeReleaseVersion(number: "8.0", build: "8A218a", release: XcodeReleaseInfo())
        let second = XcodeReleaseVersion(number: "11.0", build: "11M392q", release: XcodeReleaseInfo(gm: false, beta: 6))
        let third = XcodeReleaseVersion(number: "11.0", build: "11M374r", release: XcodeReleaseInfo(gm: false, beta: 4))

        let sorted = [second, third, first].sorted { $0 > $1 }
        XCTAssertEqual(sorted, [third, second, first])
    }

    func testTwoGMs() {
        let first = XcodeReleaseVersion(number: "10.0", build: "10A255", release: XcodeReleaseInfo())
        let second = XcodeReleaseVersion(number: "10.1", build: "10B61", release: XcodeReleaseInfo())

        let sorted = [first, second].sorted { $0 > $1 }
        XCTAssertEqual(sorted, [second, first])
    }
}
