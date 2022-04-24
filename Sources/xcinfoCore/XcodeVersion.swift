//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

public enum XcodeVersion {
    case version(String)
    case latest
}

public extension XcodeVersion {
    init(_ string: String) throws {
        if string == "latest" {
            self = .latest
        } else {
            self = .version(string)
        }
    }
}

extension XcodeVersion: CustomStringConvertible {
    public var description: String {
        switch self {
        case .latest:
            return "latest"
        case let .version(string):
            return string
        }
    }
}
