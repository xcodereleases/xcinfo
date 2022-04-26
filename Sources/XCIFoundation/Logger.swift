//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Rainbow
import Foundation

public struct Logger {
    public private(set) var isVerbose: Bool

    public init(isVerbose: Bool) {
        self.isVerbose = isVerbose
    }

    public func beginSection(_ message: String) {
        let sectionTitle = "\n\(message.cyan.bold)"
        write(sectionTitle, onSameLine: false)
    }

    public func beginParagraph(_ message: String) {
        let sectionTitle = "\n\(message.bold)"
        write(sectionTitle, onSameLine: false)
    }

    public func log(_ message: String, onSameLine: Bool = false) {
        write(message, onSameLine: onSameLine)
    }

    public func emphasized(_ message: String) {
        write(message.bold, onSameLine: false)
    }

    public func verbose(_ message: String, onSameLine: Bool = false) {
        guard isVerbose else { return }
        write(message, onSameLine: onSameLine)
    }

    public func success(_ message: String, onSameLine: Bool = false) {
        write(message.cyan, onSameLine: false)
    }

    public func error(_ message: String, onSameLine: Bool = false) {
        write(message.red, onSameLine: onSameLine)
    }

    public func warn(_ message: String, onSameLine: Bool = false) {
        write(message.yellow, onSameLine: onSameLine)
    }

    private func write(_ message: String, onSameLine: Bool) {
        var msg = message
        if onSameLine {
            msg.insert(contentsOf: "\u{1B}[1A\u{1B}[K", at: msg.startIndex)
        }
        print(msg)
        if onSameLine {
            fflush(__stdoutp)
        }
    }
}
