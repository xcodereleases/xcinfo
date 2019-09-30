//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Prompt

class NoAnsiConsolePromptPrinter: PromptPrinter {
    func printString(_ string: String, terminator: String = "\n") {
        print(string.reset(), separator: "", terminator: terminator)
    }
}
