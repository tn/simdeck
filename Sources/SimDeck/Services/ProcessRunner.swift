import Foundation

struct CommandResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var succeeded: Bool {
        exitCode == 0
    }
}

enum ProcessRunnerError: Error, UserPresentableError {
    case launchFailed(executable: String, underlying: Error)

    var userMessage: String {
        switch self {
        case .launchFailed(let executable, _):
            if executable == "/usr/bin/xcrun" {
                return "Could not find xcrun/simctl. Make sure Xcode Command Line Tools are installed."
            }
            return "Could not launch \(executable)."
        }
    }

}

final class ProcessRunner {
    func run(_ executable: String, arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(executable: executable, underlying: error)
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return CommandResult(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        }.value
    }
}
