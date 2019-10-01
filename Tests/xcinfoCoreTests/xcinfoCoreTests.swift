//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

@testable import xcinfoCore
import XCTest
import XCModel

final class xcinfoCoreTests: XCTestCase {
    func testVersionComparision() {
        let first = Version("8A218a", "8.0")
        let second = Version("11M392q", "11.0", .beta(6))
        let third = Version("11M374r", "11.0", .beta(4))

        let sorted = [second, third, first].sorted { $0 > $1 }
        XCTAssertEqual(sorted, [third, second, first])
    }

    func testTwoGMs() {
        let first = Version("10A255", "10.0")
        let second = Version("10B61", "10.1")

        let sorted = [first, second].sorted { $0 > $1 }
        XCTAssertEqual(sorted, [second, first])
    }
}
