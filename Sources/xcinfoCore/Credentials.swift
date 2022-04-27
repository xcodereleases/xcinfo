//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import Prompt
import XCIFoundation

public struct Credentials {
    public var username: String
    public var password: String
}

enum CredentialsError: Error {
    case keychainError(String)
    case invalidPassword
}

public struct CredentialProviding {
    var getCredentials: () throws -> Credentials
    var cleanup: () -> Void
}

class CredentialService {
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func appleIDCredentials() throws -> Credentials {
        if let passwordItem = try? KeychainPasswordItem.passwordItems(forService: "xcinfo.appleid").first {
            let username = passwordItem.account

            do {
                let password = try passwordItem.readPassword()
                return .init(username: username, password: password)
            } catch {
                logger.warn("Could not read password from the Keychain.")
            }
        }

        logger.log("Apple's Developer Download page requires a login.")
        logger.emphasized("Please provide your Apple Developer Program account credentials.")

        let username = try Shell.ask("Username:")
        let password = try Shell.ask("Password:", secure: true)

        logger.log("\n")
        let shouldStoreInKeychain = agree("Do you want to store these credentials in the macOS Keychain?")

        if shouldStoreInKeychain {
            do {
                let item = KeychainPasswordItem(service: "xcinfo.appleid", account: username)
                try item.savePassword(password, overwriteExisting: true)
            } catch {
                logger.warn("Could not save password to the Keychain.")
            }
        }

        return .init(username: username, password: password)
    }

    func cleanup() {
            do {
                let items = try KeychainPasswordItem.passwordItems(forService: "xcinfo.appleid")
                if !items.isEmpty {
                    for item in items {
                        try item.deleteItem()
                    }
                    logger.success("Deleted stored Apple ID credentials from keychain.")
                } else {
                    logger.log("No Apple ID credentials were stored.")
                }
            } catch {
                logger.error("Error deleting Keychain entries. Please open Keychain Access.app and remove items named 'xcinfo.appleid'.")
            }
    }
}

extension CredentialService {
    var credentialProviding: CredentialProviding {
        .init(getCredentials: appleIDCredentials, cleanup: cleanup)
    }
}

extension Credentials {
    @available(*, deprecated, message: "Use listXcodes instead")
    static func appleIDCredentials() -> (username: String, password: String) {
        if let passwordItem = try? KeychainPasswordItem.passwordItems(forService: "xcinfo.appleid").first {
            let username = passwordItem.account

            do {
                let password = try passwordItem.readPassword()
                return (username, password)
            } catch {
                fail(statusCode: 65, errorMessage: "Could not read password from the Keychain.")
            }
        } else {
            print("Apple's Developer Download page requires a login.")
            print("Please provide your Apple Developer Program account credentials.".bold)

            do {
                let username = try Shell.ask("Username:")
                let password = try Shell.ask("Password:", secure: true)

                print("\n")
                let shouldStoreInKeychain = agree("Do you want to store these credentials in the macOS Keychain?")

                if shouldStoreInKeychain {
                    do {
                        let item = KeychainPasswordItem(service: "xcinfo.appleid", account: username)
                        try item.savePassword(password, overwriteExisting: true)
                    } catch {
                        fail(statusCode: Int(EXIT_FAILURE), errorMessage: "Could not save password to the Keychain.")
                    }
                }

                return (username, password)
            } catch {
                fail(statusCode: Int(EXIT_FAILURE), errorMessage: "Invalid credentials.")
            }
        }
    }
}
