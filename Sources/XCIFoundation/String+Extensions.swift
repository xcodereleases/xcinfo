//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

extension String {
    public func paddedWithSpaces(to largestStringLength: Int) -> String {
        let lengthDelta = largestStringLength - count
        return "\(self)\(String(repeating: " ", count: lengthDelta))"
    }
}
