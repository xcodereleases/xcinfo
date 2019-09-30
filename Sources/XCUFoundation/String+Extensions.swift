//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

extension String {
    public func reset() -> String {
        replacingOccurrences(of: #"\#u{001B}\[[\d,;]*m"#, with: "", options: .regularExpression, range: nil)
    }

    public func paddedWithSpaces(to largestStringLength: Int) -> String {
        let lengthDelta = largestStringLength - count
        return "\(self)\(String(repeating: " ", count: lengthDelta))"
    }
}
