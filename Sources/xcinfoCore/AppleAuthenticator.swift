//
//  Copyright © 2022 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Combine
import Foundation
import OlympUs
import XCIFoundation

public struct AuthenticationProviding {
    var authenticate: (Credentials) async throws -> Void
}

struct AuthenticationError: Error {}

class AppleAuthenticator {
    let olymp: OlympUs
    let logger: Logger

    init(olymp: OlympUs, logger: Logger) {
        self.olymp = olymp
        self.logger = logger
    }

    var assets: OlympUs.AuthenticationAssets!
    private var cancellable: AnyCancellable?

    public func authenticate(credentials: Credentials) async throws {
        try await authenticate(username: credentials.username, password: credentials.password).singleOutput()
    }

    public func authenticate(username: String, password: String) -> Future<Void, AuthenticationError> {
        Future { [weak self] promise in
            guard let self = self else { return }
            self.cancellable = self.olymp.validateSession(for: username)
                .catch { _ in
                    self.olymp.getServiceKey(for: username)
                        .flatMap { serviceKey in
                            self.olymp.signIn(
                                accountName: username,
                                password: password,
                                serviceKey: serviceKey
                            )
                        }
                        .flatMap { authenticationAssets -> Future<ValidationType, OlympUsError> in
                            self.assets = authenticationAssets
                            return self.olymp.requestAuthentication(assets: self.assets)
                        }
                        .flatMap { validationType in
                            self.olymp.sendSecurityCode(validationType: validationType, assets: self.assets)
                        }
                        .flatMap { _ in
                            self.olymp.requestTrust(assets: self.assets)
                        }
                        .flatMap { _ in
                            self.olymp.getOlympusSession(assets: self.assets, for: username)
                        }
                }
                .flatMap { _ in
                    self.olymp
                        .getDownloadAuth(
                            assets: self.assets != nil
                            ? self.assets
                            : self.olymp.storedAuthenticationAssets(for: username)!
                        )
                }
                .sink(receiveCompletion: { _ in
                    promise(.failure(.init()))
                }, receiveValue: { _ in
                    promise(.success(()))
                })
        }
    }
}

extension AppleAuthenticator {
    var authenticationProviding: AuthenticationProviding {
        .init(authenticate: authenticate)
    }
}
