//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

extension FileManager {
    public func isSymbolicLink(atPath path: String) -> Bool {
        guard let type = try? attributesOfItem(atPath: path)[.type] as? FileAttributeType else { return false }
        return type == .typeSymbolicLink
    }
}
