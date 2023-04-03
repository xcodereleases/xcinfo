//
//  Copyright © 2023 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import RegexBuilder

struct VersionParts: Equatable {
    enum VersionType: Equatable {
        case rc(String)
        case dp(String)
        case beta(String)
        case gm(String)
    }
    var major: Int
    var minor: Int?
    var patch: Int?
    var type: VersionType?
}

extension VersionParts.VersionType {
    init?(type: String?, content: String?) {
        guard let type, let content else {
            return nil
        }
        switch type.lowercased() {
        case "beta":
            self = .beta(content)
        case "gm":
            self = .gm(content)
        case "rc":
            self = .rc(content)
        case "dp":
            self = .dp(content)
        default:
            return nil
        }
    }
}

extension VersionParts {
    init?(rawValue: String) {
        guard let version = Self.extractParts(from: rawValue) else { return nil }
        self = version
    }

    static func extractParts(from versionString: String) -> VersionParts? {
        let majorRef = Reference(Int.self)
        let minorRef = Reference(Int?.self)
        let patchRef = Reference(Int?.self)
        let typeRef = Reference(String?.self)
        let typeString = Reference(String?.self)

        let regex = Regex {
            TryCapture(as: majorRef) {
                ZeroOrMore(.digit)
            } transform: { major in
                Int(major) ?? 0
            }

            Optionally {
                "."
                TryCapture(as: minorRef) {
                    ZeroOrMore(.digit)
                } transform: { minor in
                    Int(minor)
                }
            }

            Optionally {
                "."
                TryCapture(as: patchRef) {
                    ZeroOrMore(.digit)
                } transform: { patch in
                    Int(patch)
                }
            }

            Optionally {
                OneOrMore {
                    " "
                }
                Capture(as: typeRef) {
                    ChoiceOf {
                        "beta"
                        "gm"
                        "rc"
                        "dp"
                    }
                } transform: { str in
                    String(str)
                }

                ZeroOrMore {
                    " "
                }
                Capture(as: typeString) {
                    ZeroOrMore {
                        .any
                    }
                } transform: { str in
                    String(str)
                }
            }
        }.ignoresCase()

        if let matches = try? regex.wholeMatch(in: versionString) {
            let major = matches[majorRef]
            let minor = matches[minorRef]
            let patch = matches[patchRef]
            let type = matches[typeRef]
            let str = matches[typeString]

            return .init(major: major, minor: minor, patch: patch, type: .init(type: type, content: str))
        } else {
            return nil
        }
    }
}
