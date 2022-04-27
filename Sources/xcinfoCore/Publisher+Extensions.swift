//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine

extension Publishers {
    struct MissingOutputError: Error {}
}

extension Publisher {
    func singleOutput() async throws -> Output {
        var cancellable: AnyCancellable?
        var didReceiveValue = false

        return try await withCheckedThrowingContinuation { continuation in
            cancellable = sink(
                receiveCompletion: { completion in
                    switch completion {
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    case .finished:
                        if !didReceiveValue {
                            continuation.resume(
                                throwing: Publishers.MissingOutputError()
                            )
                        }
                    }
                },
                receiveValue: { value in
                    guard !didReceiveValue else { return }

                    didReceiveValue = true
                    cancellable?.cancel()
                    continuation.resume(returning: value)
                }
            )
        }
    }
}
