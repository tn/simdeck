import Foundation

struct ScreenshotOutcome {
    let outputURL: URL
    let simulator: SimulatorDevice
    let warnings: [String]
}

enum ScreenshotError: Error, UserPresentableError {
    case outputDirectoryFailed(URL, Error)
    case rawScreenshotMissing

    var userMessage: String {
        switch self {
        case .outputDirectoryFailed:
            return "Could not create the output folder."
        case .rawScreenshotMissing:
            return "Could not capture screenshot. Check that the simulator is running."
        }
    }

}

final class ScreenshotService {
    private let simctlService: SimctlService
    private let frameRenderer: DeviceFrameRenderer

    init(simctlService: SimctlService, frameRenderer: DeviceFrameRenderer) {
        self.simctlService = simctlService
        self.frameRenderer = frameRenderer
    }

    func takeScreenshot(settings: AppSettings, filenameAppearanceVariant: AppearanceMode? = nil) async throws -> ScreenshotOutcome {
        let simulator = try await simctlService.resolveTargetSimulator(settings: settings)
        var warnings: [String] = []

        do {
            try FileManager.default.createDirectory(at: settings.outputFolderURL, withIntermediateDirectories: true)
        } catch {
            throw ScreenshotError.outputDirectoryFailed(settings.outputFolderURL, error)
        }

        let rawURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("simdeck_raw_\(UUID().uuidString)")
            .appendingPathExtension("png")
        let finalURL = FileNameBuilder.outputURL(
            in: settings.outputFolderURL,
            pattern: settings.filenamePattern,
            simulator: simulator,
            framed: settings.deviceFrameEnabled,
            appearanceVariant: filenameAppearanceVariant
        )

        var shouldClearStatusBar = settings.prettyStatusBarEnabled

        var settleDelayNanoseconds: UInt64 = 300_000_000

        do {
            if settings.prettyStatusBarEnabled {
                do {
                    try await simctlService.statusBarOverride(device: simulator, preset: settings.statusBarPreset)
                } catch {
                    shouldClearStatusBar = true
                    warnings.append("Screenshot saved, but status bar override failed.")
                }
            }

            if settings.appearanceMode != .doNotChange {
                do {
                    try await simctlService.setAppearance(device: simulator, appearance: settings.appearanceMode)
                    settleDelayNanoseconds = 1_100_000_000
                } catch {
                    warnings.append("Screenshot saved, but appearance override failed.")
                }
            }

            try await Task.sleep(nanoseconds: settleDelayNanoseconds)
            try await simctlService.captureScreenshot(
                device: simulator,
                outputURL: rawURL,
                mask: settings.deviceFrameEnabled ? .ignored : nil
            )
        } catch {
            if shouldClearStatusBar {
                try? await simctlService.clearStatusBar(device: simulator)
            }
            throw error
        }

        if shouldClearStatusBar {
            try? await simctlService.clearStatusBar(device: simulator)
        }

        guard FileManager.default.fileExists(atPath: rawURL.path) else {
            throw ScreenshotError.rawScreenshotMissing
        }

        if settings.deviceFrameEnabled {
            do {
                try frameRenderer.render(
                    rawScreenshot: rawURL,
                    outputURL: finalURL,
                    options: settings.frameOptions,
                    simulator: simulator
                )
                try? FileManager.default.removeItem(at: rawURL)
            } catch {
                warnings.append("Raw screenshot saved, but device frame rendering failed.")
                if FileManager.default.fileExists(atPath: finalURL.path) {
                    try? FileManager.default.removeItem(at: finalURL)
                }
                try FileManager.default.moveItem(at: rawURL, to: finalURL)
            }
        } else {
            try FileManager.default.moveItem(at: rawURL, to: finalURL)
        }

        return ScreenshotOutcome(
            outputURL: finalURL,
            simulator: simulator,
            warnings: warnings
        )
    }
}
