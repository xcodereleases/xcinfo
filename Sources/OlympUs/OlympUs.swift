//
//  Copyright © 2019 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Colorizer
import Combine
import Foundation
import Prompt
import XCIFoundation

public enum OlympUsError: Error {
    case missingSessionKey
    case signInRequestFailed
    case requestAuthentication
    case requestSmsFailed
    case deviceTrustFailed
    case olympusSessionFailed
    case downloadAuthFailed
    case sessionInvalid
}

public enum OlympUsState: CaseIterable, CustomStringConvertible {
    case validatingExistingSession
    case requestingServiceKey
    case signingIn
    case requestingAuth
    case sendingSecurityCode
    case requestingTrust
    case gettingSession
    case gettingDownloadAuth

    public var description: String {
        switch self {
        case .validatingExistingSession:
            return "Validating existing session"
        case .requestingServiceKey:
            return "Requesting service key"
        case .signingIn:
            return "Signing in with credentials"
        case .requestingAuth:
            return "Requesting authentication"
        case .sendingSecurityCode:
            return "Sending security code"
        case .requestingTrust:
            return "Requesting trust"
        case .gettingSession:
            return "Requesting download session"
        case .gettingDownloadAuth:
            return "Requesting download auth info"
        }
    }
}

public enum ValidationType {
    case securityCode(String)
    case verificationCode(Int, String)
}

private struct SecurityCode: Codable {
    let code: String
}

private struct VerifyPhoneRequest: Codable {
    struct TrustedNumber: Codable {
        let id: Int
    }

    let phoneNumber: VerifyPhoneRequest.TrustedNumber
    let mode = "sms"
    var securityCode: SecurityCode? = nil
}

private struct VerifyTrustedDeviceRequest: Codable {
    let securityCode: SecurityCode
}

extension ValidationType {
    var verificationURL: URL {
        switch self {
        case .securityCode:
            return URL(string: "https://idmsa.apple.com/appleauth/auth/verify/trusteddevice/securitycode")!
        case .verificationCode:
            return URL(string: "https://idmsa.apple.com/appleauth/auth/verify/phone/securitycode")!
        }
    }

    var body: Data {
        switch self {
        case let .securityCode(code):
            let body = VerifyTrustedDeviceRequest(securityCode: SecurityCode(code: code))
            return try! JSONEncoder().encode(body)
        case let .verificationCode(phoneId, code):
            let body = VerifyPhoneRequest(phoneNumber: VerifyPhoneRequest.TrustedNumber(id: phoneId), securityCode: SecurityCode(code: code))
            return try! JSONEncoder().encode(body)
        }
    }
}

public class URLSessionDelegateProxy: NSObject, URLSessionDownloadDelegate {
    public private(set) var proxies: [URLSessionDownloadDelegate] = []

    public func add(proxy: URLSessionDownloadDelegate) {
        proxies.append(proxy)
    }

    public func remove(proxy: URLSessionDownloadDelegate) {
        proxies.removeAll { delegate in
            delegate.isEqual(proxy)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        proxies.forEach { proxy in
            proxy.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        proxies.forEach { proxy in
            proxy.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        proxies.forEach { proxy in
            proxy.urlSession?(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }
    }
}

extension OlympUs.AuthenticationAssets: Codable {}

public class OlympUs {
    private var disposeBag = Set<AnyCancellable>()
    private let logger: Logger
    
    public private(set) var state: OlympUsState? {
        didSet {
            displayState()
        }
    }

    public let session: URLSession

    public init(logger: Logger, session: URLSession) {
        self.logger = logger
        self.session = session
        restoreCookies()
    }

    private func displayState() {
        guard let state = state, let index = OlympUsState.allCases.firstIndex(of: state) else { return }
        let message = "[\(index)/\(OlympUsState.allCases.count - 1)] \(state.description)"
        logger.log(message, onSameLine: state != OlympUsState.allCases.first!)
    }

    // MARK: - Step 0: request a service key a.k.a. widget key -

    struct ServiceKeyResponse: Codable {
        var authServiceKey: String
    }

    public func storedAuthenticationAssets(for account: String) -> AuthenticationAssets? {
        let item = KeychainPasswordItem(
            service: "xcinfo.session",
            account: account
        )
        do {
            let codedAssets = try item.readData()
            return try JSONDecoder().decode(AuthenticationAssets.self, from: codedAssets)
        } catch {
            return nil
        }
    }

    @discardableResult
    private func storeAuthenticationAssets(assets: AuthenticationAssets, for account: String) -> Bool {
        let item = KeychainPasswordItem(
            service: "xcinfo.session",
            account: account
        )
        do {
            let data = try JSONEncoder().encode(assets)
            try item.saveData(data, overwriteExisting: true)
            return true
        } catch {
            return false
        }
    }

    public func validateSession(for account: String) -> Future<Void, OlympUsError> {
        Future { promise in
            self.state = .validatingExistingSession
            guard let assets = self.storedAuthenticationAssets(for: account) else {
                promise(.failure(.sessionInvalid))
                return
            }
            self.getOlympusSession(assets: assets, for: account)
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        self.logger.verbose("Session invalid. Starting authentication.")
                        promise(.failure(.sessionInvalid))
                    }
                }, receiveValue: { _ in
                    self.logger.verbose("Reusing valid session.")
                    promise(.success(()))
                })
                .store(in: &self.disposeBag)
        }
    }

    private var sessionKeyURL = URL(string: "https://appstoreconnect.apple.com/olympus/v1/app/config")!
    public func getServiceKey(for account: String) -> Future<String, OlympUsError> {
        Future { promise in
            self.state = .requestingServiceKey
            if let serviceKey = self.storedAuthenticationAssets(for: account)?.serviceKey {
                promise(.success(serviceKey))
            } else {
                var components = URLComponents(url: self.sessionKeyURL, resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "hostname", value: "itunesconnect.apple.com")]
                self.session
                    .dataTaskPublisher(for: components.url!)
                    .map { $0.data }
                    .decode(type: ServiceKeyResponse.self, decoder: JSONDecoder())
                    .sink(receiveCompletion: { completion in
                        if case .failure = completion {
                            promise(.failure(.missingSessionKey))
                        }
                    }, receiveValue: { response in
                        promise(.success(response.authServiceKey))
                    })
                    .store(in: &self.disposeBag)
            }
        }
    }

    // MARK: - Step 1: sign in -

    struct SignInRequest: Codable {
        var accountName: String
        var password: String
        var rememberMe = true
    }

    struct SignInResponse: Codable {
        var authType: String
    }

    private let signInURL = URL(string: "https://idmsa.apple.com/appleauth/auth/signin")!

    public struct AuthenticationAssets {
        var serviceKey: String?
        var scnt: String?
        var asid: String?
        var authenticationType: String?
    }

    public func signIn(accountName: String, password: String, serviceKey: String) -> Future<AuthenticationAssets, OlympUsError> {
        Future { promise in
            self.state = .signingIn
            self.session.configuration.httpCookieStorage?.removeCookies(since: Date(timeIntervalSinceReferenceDate: 0))

            var request = URLRequest(url: self.signInURL)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("X-Requested-With", forHTTPHeaderField: "X-Requested-With")
            request.addValue("application/json, text/javascript", forHTTPHeaderField: "Accept")
            request.addValue(serviceKey, forHTTPHeaderField: "X-Apple-Widget-Key")

            let body = SignInRequest(accountName: accountName, password: password)
            let data = try? JSONEncoder().encode(body)

            var authenticationAssets = AuthenticationAssets(serviceKey: serviceKey)
            request.httpBody = data
            self.session
                .dataTaskPublisher(for: request)
                .map {
                    if
                        let httpResponse = $0.response as? HTTPURLResponse,
                        let scnt = httpResponse.allHeaderFields["scnt"] as? String,
                        let asid = httpResponse.allHeaderFields["X-Apple-ID-Session-Id"] as? String {
                        authenticationAssets.asid = asid
                        authenticationAssets.scnt = scnt
                    }
                    return $0.data
                }
                .decode(type: SignInResponse.self, decoder: JSONDecoder())
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.signInRequestFailed))
                    }
                }, receiveValue: { response in
                    authenticationAssets.authenticationType = response.authType
                    promise(.success(authenticationAssets))
                })
                .store(in: &self.disposeBag)
        }
    }

    // MARK: - Step 2: request auth -

    private let authURL = URL(string: "https://idmsa.apple.com/appleauth/auth")!
    private let verifyPhoneURL = URL(string: "https://idmsa.apple.com/appleauth/auth/verify/phone")!
    public struct TrustedNumber: Codable {
        let numberWithDialCode: String
        let pushMode: String
        let obfuscatedNumber: String
        let id: Int
    }

    public struct CodeDescription: Codable {
        let length: Int
        let tooManyCodesSent: Bool
        let tooManyCodesValidated: Bool
        let securityCodeLocked: Bool
    }

    private struct RequestAuthResponse: Codable {
        let trustedPhoneNumbers: [TrustedNumber]
        let securityCode: CodeDescription
    }

    enum HttpMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }

    public func requestAuthentication(assets: AuthenticationAssets) -> Future<ValidationType, OlympUsError> {
        Future { promise in
            self.state = .requestingAuth
            self.session
                .dataTaskPublisher(for: self.request(forURL: self.authURL, assets: assets, method: .post))
                .map { $0.data }
                .decode(type: RequestAuthResponse.self, decoder: JSONDecoder())
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.requestAuthentication))
                    }
                }, receiveValue: { response in
                    let requiredCodeLength = response.securityCode.length
                    self.logger.log("\nTwo-factor authentication is enabled for your account.")
                    self.logger.log("Please enter a \(requiredCodeLength) digit verification code generated on one of your trusted devices.")
                    self.logger.log("Type '\("sms".f.Magenta)' to receive a verification code on a trusted phone number.")
                    let input = ask("Apple ID Verification Code: ", type: String.self) { settings in
                        settings.addInvalidCase("Invalide code length") { value in
                            value != "sms" && requiredCodeLength != value.count
                        }
                    }
                    switch input {
                    case "sms":
                        let phoneId = choose("Please choose your trusted device: ", type: Int.self) { settings in
                            for number in response.trustedPhoneNumbers {
                                settings.addChoice(number.numberWithDialCode) { number.id }
                            }
                        }
                        var request = self.request(forURL: self.verifyPhoneURL, assets: assets, method: .put)
                        let body = VerifyPhoneRequest(phoneNumber: VerifyPhoneRequest.TrustedNumber(id: phoneId))
                        let data = try? JSONEncoder().encode(body)
                        request.httpBody = data

                        self.session
                            .dataTaskPublisher(for: request)
                            .sink(receiveCompletion: { completion in
                                if case .failure = completion {
                                    promise(.failure(.requestSmsFailed))
                                }
                            }, receiveValue: { _ in
                                let smsCode = ask("Please enter the received verification code:", type: String.self) { settings in
                                    settings.addInvalidCase("Invalid code length") { value in
                                        requiredCodeLength != value.count
                                    }
                                }
                                self.logger.log("\n")
                                promise(.success(.verificationCode(phoneId, smsCode)))
                            })
                            .store(in: &self.disposeBag)
                    default:
                        self.logger.log("\n")
                        promise(.success(.securityCode(input)))
                    }
                })
                .store(in: &self.disposeBag)
        }
    }

//    MARK: - send security code -

    public func sendSecurityCode(validationType: ValidationType, assets: AuthenticationAssets) -> Future<Int, OlympUsError> {
        Future { promise in
            self.state = .sendingSecurityCode
            var request = self.request(forURL: validationType.verificationURL, assets: assets, method: .post)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = validationType.body
            self.session
                .dataTaskPublisher(for: request)
                .map {
                    $0.response
                }
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.deviceTrustFailed))
                    }
                }, receiveValue: { response in
                    if let httpResponse = response as? HTTPURLResponse {
                        promise(.success(httpResponse.statusCode))
                    } else {
                        promise(.failure(.deviceTrustFailed))
                    }
                })
                .store(in: &self.disposeBag)
        }
    }

//    MARK: - requesting trust -

    private let trustURL = URL(string: "https://idmsa.apple.com/appleauth/auth/2sv/trust")!
    public func requestTrust(assets: AuthenticationAssets) -> Future<[HTTPCookie], OlympUsError> {
        Future { promise in
            self.state = .requestingTrust
            let request = self.request(forURL: self.trustURL, assets: assets, method: .get)
            self.session
                .dataTaskPublisher(for: request)
                .map { $0.response }
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.deviceTrustFailed))
                    }
                }, receiveValue: { response in
                    if let httpResponse = response as? HTTPURLResponse {
                        let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: self.trustURL)
                        promise(.success(responseCookies))
                    } else {
                        promise(.failure(.deviceTrustFailed))
                    }
                })
                .store(in: &self.disposeBag)
        }
    }

//    MARK: - get session from Olympus -

    private let olympusSessionURL = URL(string: "https://appstoreconnect.apple.com/olympus/v1/session")!
    public func getOlympusSession(assets: AuthenticationAssets, for account: String) -> Future<Void, OlympUsError> {
        Future { promise in
            self.state = .gettingSession
            let request = self.request(forURL: self.olympusSessionURL, assets: assets, method: .get)
            self.session
                .dataTaskPublisher(for: request)
                .map { $0.response }
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.olympusSessionFailed))
                    }
                }, receiveValue: { response in
                    if self.handle(response: response) {
                        self.storeAuthenticationAssets(assets: assets, for: account)
                        promise(.success(()))
                    } else {
                        promise(.failure(.olympusSessionFailed))
                    }
                })
                .store(in: &self.disposeBag)
        }
    }

    private func handle(response: URLResponse) -> Bool {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            return false
        }

        let allHeaderFields = response.allHeaderFields

        guard let originalCookies = allHeaderFields["Set-Cookie"] as? String else {
            return true
        }

        let regex = try! NSRegularExpression(pattern: #"(?<!Expires=\w{3}),"#, options: [])
        var cookieDict: [String: String] = [:]
        var startIndex = originalCookies.startIndex
        regex.enumerateMatches(in: originalCookies,
                               options: [],
                               range: NSRange(originalCookies.startIndex..., in: originalCookies)) { result, _, _ in
            guard let nsrange = result?.range, let range = Range<String.Index>(nsrange, in: originalCookies) else { return }
            let match = originalCookies[startIndex ..< range.lowerBound]
            startIndex = range.upperBound
            let keyValuePair = match.split(separator: "=")
            let key = String(keyValuePair[0]).trimmingCharacters(in: .whitespaces)
            cookieDict[key] = String(keyValuePair.dropFirst().joined(separator: "="))
        }

        let lastMatch = originalCookies[startIndex...]
        let keyValuePair = lastMatch.split(separator: "=")
        let key = String(keyValuePair[0]).trimmingCharacters(in: .whitespaces)
        cookieDict[key] = String(keyValuePair.dropFirst().joined(separator: "="))

        let appleURL = URL(string: "apple.com")!
        let cookies = cookieDict
            .flatMap { HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "\($0.key)=\($0.value)"], for: appleURL) }

        cookies.forEach {
            self.session.configuration.httpCookieStorage?.setCookie($0)
        }

        storeCookies()
        return true
    }

    private let downloadAuthURL = URL(string: "https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action")!
    public func getDownloadAuth(assets: AuthenticationAssets) -> Future<Void, OlympUsError> {
        Future { promise in
            self.state = .gettingDownloadAuth
            let request = self.request(forURL: self.downloadAuthURL, assets: assets, method: .post)
            self.session
                .dataTaskPublisher(for: request)
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        promise(.failure(.downloadAuthFailed))
                    }
                }, receiveValue: { output in
                    if self.handle(response: output.response),
                        self.session.configuration.httpCookieStorage?.cookies?.contains(where: { $0.name == "ADCDownloadAuth" }) == true {
                        promise(.success(()))
                    } else {
                        promise(.failure(.downloadAuthFailed))
                    }
                })
                .store(in: &self.disposeBag)
        }
    }

//    MARK: - Helpers -

    private func request(forURL url: URL, assets: AuthenticationAssets, method: HttpMethod = .get) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue(assets.serviceKey!, forHTTPHeaderField: "X-Apple-Widget-Key")
        request.addValue(assets.scnt!, forHTTPHeaderField: "scnt")
        request.addValue(assets.asid!, forHTTPHeaderField: "X-Apple-ID-Session-Id")
        if [HttpMethod.post, .put].contains(method) {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
        }
        return request
    }
}

//    MARK: - Cookies -

extension OlympUs {
    private func storeCookies() {
        guard let cookies = session.configuration.httpCookieStorage?.cookies else { return }

        let userDefaults = UserDefaults.standard
        let cookiesArray = cookies.compactMap { $0.properties }
        userDefaults.set(cookiesArray, forKey: "cookies")
    }

    private func restoreCookies() {
        guard let cookieStorage = session.configuration.httpCookieStorage else { return }

        let userDefaults = UserDefaults.standard

        if let cookies = userDefaults.array(forKey: "cookies") as? [[HTTPCookiePropertyKey: Any]] {
            for cookieProperties in cookies {
                if let cookie = HTTPCookie(properties: cookieProperties) {
                    cookieStorage.setCookie(cookie)
                }
            }
        }
    }
}
