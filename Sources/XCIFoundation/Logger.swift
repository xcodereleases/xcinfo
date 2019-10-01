//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
import Foundation

public struct Logger {
    public private(set) var useANSI: Bool
    public private(set) var isVerbose: Bool

    public init(isVerbose: Bool, useANSI: Bool) {
        self.isVerbose = isVerbose
        self.useANSI = useANSI
    }

    public func beginSection(_ message: String) {
        let sectionTitle = "\n\(message.f.Cyan.s.Bold)"
        write(useANSI ? sectionTitle : sectionTitle.reset(), onSameLine: false)
    }

    public func beginParagraph(_ message: String) {
        let sectionTitle = "\n\(message.s.Bold)"
        write(useANSI ? sectionTitle : sectionTitle.reset(), onSameLine: false)
    }

    public func log(_ message: String, onSameLine: Bool = false) {
        write(useANSI ? message : message.reset(), onSameLine: onSameLine)
    }

    public func verbose(_ message: String, onSameLine: Bool = false) {
        guard isVerbose else { return }
        write(useANSI ? message : message.reset(), onSameLine: onSameLine)
    }

    public func success(_ message: String) {
        write(useANSI ? message.f.Cyan : message.reset(), onSameLine: false)
    }

    public func error(_ message: String) {
        write(useANSI ? message.f.Red : message.reset(), onSameLine: false)
    }

    private func write(_ message: String, onSameLine: Bool) {
        var msg = message
        if onSameLine, useANSI {
            msg.insert(contentsOf: "\u{1B}[1A\u{1B}[K", at: msg.startIndex)
        }
        print(msg)
        if onSameLine, useANSI {
            fflush(__stdoutp)
        }
    }
}
