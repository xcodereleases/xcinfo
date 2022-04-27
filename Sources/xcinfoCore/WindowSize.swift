//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Darwin
import Foundation

struct WindowSize {
    var rows: Int
    var columns: Int
    var pixelWidth: Int
    var pixelHeight: Int

    static var current: WindowSize? = {
        var w = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0, w.ws_col != 0 else {
            return nil
        }

        return WindowSize(
            rows: Int(w.ws_row),
            columns: Int(w.ws_col),
            pixelWidth: Int(w.ws_xpixel),
            pixelHeight: Int(w.ws_ypixel)
        )
    }()
}
