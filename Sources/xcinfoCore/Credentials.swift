//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import Prompt
import XCIFoundation

public enum Credentials {
    enum CredentialsError: Error {
        case invalidPassword
    }
    
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
                let username = try Self.ask(prompt: "Username:")
                let password = try Self.ask(prompt: "Password:", secure: true)

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

    public static func ask(prompt: String, secure: Bool = false, validation: (String) -> Bool = { _ in true }) throws -> String {
        if secure {
            let pwd = String(cString: getpass("\(prompt) "))
            if validation(pwd) {
                return pwd
            } else {
                throw CredentialsError.invalidPassword
            }
        } else {
            print("\(prompt) ", terminator: "")
            let result = readLine() ?? ""
            return result
        }
    }
}
