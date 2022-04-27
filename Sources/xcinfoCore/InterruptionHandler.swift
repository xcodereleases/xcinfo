//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

final class InterruptionHandler {
    private let signalSource: DispatchSourceSignal

    init(handler: @escaping (Bool) -> Void) {
        signal(SIGINT, SIG_IGN)

        signalSource = DispatchSource.makeSignalSource(signal: SIGINT)

        var interrupted: sig_atomic_t = 0
        signalSource.setEventHandler {
            handler(interrupted == 1)
            interrupted = 1
        }
        signalSource.resume()
    }

    deinit {
        signalSource.cancel()
        signal(SIGINT, SIG_DFL)
    }
}
