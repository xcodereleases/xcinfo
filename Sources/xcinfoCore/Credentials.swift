//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation
import Guaka
import Prompt
import XCIFoundation

public enum Credentials {
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
            print("Please provide your Apple Developer Program account credentials.".s.Bold)

            let username = Self.ask(prompt: "Username:")
            let password = Self.ask(prompt: "Password:", secure: true)

            print("\n")
            let shouldStoreInKeychain = agree("Do you want to store these credentials in the macOS Keychain?")

            if shouldStoreInKeychain {
                do {
                    let item = KeychainPasswordItem(service: "xcinfo.appleid", account: username)
                    try item.savePassword(password, overwriteExisting: true)
                } catch {
                    fail(statusCode: 65, errorMessage: "Could not save password to the Keychain.")
                }
            }

            return (username, password)
        }
    }

    public static func ask(prompt: String, secure: Bool = false) -> String {
        if secure {
            return String(cString: getpass("\(prompt) "))
        } else {
            print("\(prompt) ", terminator: "")
            let result = readLine() ?? ""
            return result
        }
    }
}
