import Foundation

enum SimctlError: Error, UserPresentableError {
    case noBootedSimulator
    case selectedSimulatorNotFound
    case selectedSimulatorNotBooted(String)
    case commandFailed(command: String, stderr: String)
    case invalidDevicesJSON

    var userMessage: String {
        switch self {
        case .noBootedSimulator:
            return "No booted iOS Simulator found. Start a simulator and try again."
        case .selectedSimulatorNotFound:
            return "Selected simulator was not found. Pick another simulator or use the booted one."
        case .selectedSimulatorNotBooted(let name):
            return "\(name) is not booted. Start it and try again."
        case .commandFailed(let command, _):
            if command.contains("io") && command.contains("screenshot") {
                return "Could not capture screenshot. Check that the simulator is running."
            }
            return "Simulator command failed."
        case .invalidDevicesJSON:
            return "Could not read simulator list from simctl."
        }
    }

}

final class SimctlService {
    private let processRunner: ProcessRunner
    private let xcrunPath = "/usr/bin/xcrun"

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func listDevices() async throws -> [SimulatorDevice] {
        let result = try await runSimctl(["list", "devices", "--json"])
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl list devices --json", stderr: result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw SimctlError.invalidDevicesJSON
        }

        do {
            let response = try JSONDecoder().decode(SimctlDevicesResponse.self, from: data)
            return response.devices.flatMap { runtime, devices in
                devices
                    .filter { runtime.contains("iOS") && $0.isAvailable }
                    .map {
                        SimulatorDevice(
                            name: $0.name,
                            udid: $0.udid,
                            state: $0.state,
                            runtime: runtimeDisplayName(from: runtime),
                            deviceTypeIdentifier: $0.deviceTypeIdentifier
                        )
                    }
            }
            .sorted { lhs, rhs in
                if lhs.isBooted != rhs.isBooted {
                    return lhs.isBooted
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            throw SimctlError.invalidDevicesJSON
        }
    }

    func resolveTargetSimulator(settings: AppSettings) async throws -> SimulatorDevice {
        let devices = try await listDevices()

        if settings.useBootedSimulatorAutomatically {
            guard let booted = devices.first(where: \.isBooted) else {
                throw SimctlError.noBootedSimulator
            }
            return booted
        }

        guard let selectedUDID = settings.selectedDeviceUDID else {
            guard let booted = devices.first(where: \.isBooted) else {
                throw SimctlError.noBootedSimulator
            }
            return booted
        }

        guard let selected = devices.first(where: { $0.udid == selectedUDID }) else {
            throw SimctlError.selectedSimulatorNotFound
        }

        guard selected.isBooted else {
            throw SimctlError.selectedSimulatorNotBooted(selected.name)
        }

        return selected
    }

    func statusBarOverride(device: SimulatorDevice, preset: StatusBarPreset) async throws {
        var arguments = [
            "status_bar",
            device.udid,
            "override",
            "--time",
            preset.time,
            "--batteryState",
            preset.batteryState.rawValue,
            "--batteryLevel",
            "\(clamp(preset.batteryLevel, min: 0, max: 100))",
            "--wifiBars",
            "\(clamp(preset.wifiBars, min: 0, max: 3))",
            "--cellularBars",
            "\(clamp(preset.cellularBars, min: 0, max: 4))"
        ]

        if !preset.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--operatorName", preset.operatorName])
        }

        if preset.dataNetwork != .none {
            arguments.append(contentsOf: ["--dataNetwork", preset.dataNetwork.rawValue])
        }

        let result = try await runSimctl(arguments)
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl \(arguments.joined(separator: " "))", stderr: result.stderr)
        }
    }

    func clearStatusBar(device: SimulatorDevice) async throws {
        let arguments = ["status_bar", device.udid, "clear"]
        let result = try await runSimctl(arguments)
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl status_bar \(device.udid) clear", stderr: result.stderr)
        }
    }

    func setAppearance(device: SimulatorDevice, appearance: AppearanceMode) async throws {
        guard let argument = appearance.simctlArgument else {
            return
        }

        let arguments = ["ui", device.udid, "appearance", argument]
        let result = try await runSimctl(arguments)
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl ui \(device.udid) appearance \(argument)", stderr: result.stderr)
        }
    }

    func currentAppearance(device: SimulatorDevice) async throws -> AppearanceMode? {
        let arguments = ["ui", device.udid, "appearance"]
        let result = try await runSimctl(arguments)
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl ui \(device.udid) appearance", stderr: result.stderr)
        }

        switch result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    func captureScreenshot(device: SimulatorDevice, outputURL: URL, mask: ScreenshotMask? = nil) async throws {
        var arguments = ["io", device.udid, "screenshot"]
        if let mask {
            arguments.append(contentsOf: ["--mask", mask.rawValue])
        }
        arguments.append(outputURL.path)
        let result = try await runSimctl(arguments)
        guard result.succeeded else {
            throw SimctlError.commandFailed(command: "simctl \(arguments.joined(separator: " "))", stderr: result.stderr)
        }
    }

    private func runSimctl(_ arguments: [String]) async throws -> CommandResult {
        try await processRunner.run(xcrunPath, arguments: ["simctl"] + arguments)
    }

    private func runtimeDisplayName(from runtimeIdentifier: String) -> String {
        runtimeIdentifier
            .replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func clamp(_ value: Int, min lowerBound: Int, max upperBound: Int) -> Int {
        min(max(value, lowerBound), upperBound)
    }
}

enum ScreenshotMask: String {
    case alpha
    case black
    case ignored
}
