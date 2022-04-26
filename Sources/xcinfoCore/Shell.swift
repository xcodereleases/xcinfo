//
//  Copyright © 2020 xcodereleases.com
//  MIT license - see LICENSE.md
//

import Foundation

typealias ProcessExecutionResult = (exitStatus: Int, stdout: String, stderr: String)

struct Shell {
    static func execute(_ command: String, args: String...) -> ProcessExecutionResult {
        execute(command, args: args)
    }

    static func execute(_ command: String, args: [String] = []) -> ProcessExecutionResult {
        let process = Process()

        process.launchPath = "/usr/bin/env"
        process.arguments = [command] + args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.launch()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return (Int(process.terminationStatus), stdout, stderr)
    }

    static func executePrivileged(command: String, password: String, args: String...) -> ProcessExecutionResult {
        executePrivileged(command: command, password: password, args: args)
    }

    static func executePrivileged(command: String, password: String, args: [String] = []) -> ProcessExecutionResult {
        let p1 = Process()
        p1.launchPath = "/bin/echo"
        p1.arguments = [password]

        let p2 = Process()
        p2.launchPath = "/usr/bin/sudo"
        p2.arguments = ["-S", command] + args

        let pipeBetween = Pipe()
        p1.standardOutput = pipeBetween
        p2.standardInput = pipeBetween

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        p2.standardOutput = stdoutPipe
        p2.standardError = stderrPipe

        p1.launch()
        p1.waitUntilExit()

        p2.launch()
        p2.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return (Int(p2.terminationStatus), stdout, stderr)
    }

    static func ask(_ prompt: String, secure: Bool = false, validation: (String) -> Bool = { _ in true }) throws -> String {
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
