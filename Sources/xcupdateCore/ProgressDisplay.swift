//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

struct ProgressDisplay {
    var ratio: Double
    let width: Int
    var fullChar = "█"
    var partChars = [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]

    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en-US")
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        formatter.numberStyle = .percent
        return formatter
    }()

    var representation: String {
        let progress = min(1, max(0, ratio))
        let widthPercentage = progress * Double(width)
        let fullCharWidth = widthPercentage.rounded(.down)
        let partCharWidth = widthPercentage - fullCharWidth

        let partWidth = Int(partCharWidth * Double(partChars.count))
        let fullChars = String(repeating: "█", count: Int(fullCharWidth))
        if fullCharWidth < Double(width) {
            let emptyChars = String(repeating: " ", count: Int(Double(width) - fullCharWidth - 1))
            let bar = fullChars + partChars[partWidth] + emptyChars
            return "[\(bar.f.Cyan)] \(formatter.string(for: ratio) ?? "0")"
        } else {
            return "[\(fullChars)] 100.0%"
        }
    }
}
