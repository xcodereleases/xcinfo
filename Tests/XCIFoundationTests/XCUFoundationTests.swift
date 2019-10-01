//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
@testable import XCIFoundation
import XCTest

final class XCIFoundationTests: XCTestCase {
    func testResetString() {
        let str = "Hello World".f.Green
        XCTAssertEqual(str.reset(), "Hello World")

        let str2 = "Hello \("green".f.Green) World"
        XCTAssertEqual(str2.reset(), "Hello green World")
    }
}
