import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            settingsStore.save(settings)
        }
    }

    @Published private(set) var devices: [SimulatorDevice] = []
    @Published private(set) var isCapturing = false
    @Published private(set) var lastScreenshotURL: URL?
    @Published var lastErrorMessage: String?
    @Published var lastWarningMessage: String?

    private let settingsStore = AppSettingsStore()
    private let simctlService: SimctlService
    private let screenshotService: ScreenshotService
    private let clipboardService = ClipboardService()
    private let notificationService = NotificationService()
    private var settingsWindow: NSWindow?

    init() {
        let runner = ProcessRunner()
        let simctlService = SimctlService(processRunner: runner)
        self.simctlService = simctlService
        self.screenshotService = ScreenshotService(
            simctlService: simctlService,
            frameRenderer: DeviceFrameRenderer()
        )
        self.settings = settingsStore.load()

        Task {
            await refreshDevices()
        }
    }

    var deviceSummary: String {
        if let booted = devices.first(where: \.isBooted) {
            return booted.name
        }
        return "No booted simulator"
    }

    func refreshDevices() async {
        do {
            devices = try await simctlService.listDevices()
            lastErrorMessage = nil
        } catch {
            devices = []
            lastErrorMessage = userMessage(for: error)
        }
    }

    func takePrettyScreenshot(lightAndDark: Bool = false) async {
        guard !isCapturing else {
            return
        }

        isCapturing = true
        lastErrorMessage = nil
        lastWarningMessage = nil
        defer {
            isCapturing = false
        }

        let captureSettings = settings

        var appearanceRestoreDevice: SimulatorDevice?
        var appearanceToRestore: AppearanceMode?

        do {
            let outcomes: [ScreenshotOutcome]
            if lightAndDark {
                appearanceRestoreDevice = try? await simctlService.resolveTargetSimulator(settings: captureSettings)
                if let appearanceRestoreDevice {
                    appearanceToRestore = try? await simctlService.currentAppearance(device: appearanceRestoreDevice)
                }

                outcomes = try await captureScreenshots(
                    for: [.light, .dark],
                    settings: captureSettings
                )
            } else {
                outcomes = [try await screenshotService.takeScreenshot(settings: captureSettings)]
            }

            guard let lastOutcome = outcomes.last else {
                await restoreAppearance(appearanceToRestore, device: appearanceRestoreDevice)
                return
            }

            await restoreAppearance(appearanceToRestore, device: appearanceRestoreDevice)

            let warnings = outcomes.flatMap(\.warnings)
            lastScreenshotURL = lastOutcome.outputURL
            lastWarningMessage = warnings.isEmpty ? nil : warnings.joined(separator: "\n")

            if settings.copyToClipboardAfterScreenshot {
                try? clipboardService.copyImage(at: lastOutcome.outputURL)
            }

            if settings.revealInFinderAfterScreenshot {
                NSWorkspace.shared.activateFileViewerSelecting(outcomes.map(\.outputURL))
            }

            if settings.showNotificationAfterScreenshot {
                let body = warnings.isEmpty
                    ? outcomes.map { $0.outputURL.lastPathComponent }.joined(separator: "\n")
                    : warnings.joined(separator: "\n")
                await notificationService.show(title: "Screenshot saved", body: body)
            }

            await refreshDevices()
        } catch {
            await restoreAppearance(appearanceToRestore, device: appearanceRestoreDevice)
            let message = userMessage(for: error)
            lastErrorMessage = message
            if settings.showNotificationAfterScreenshot {
                await notificationService.show(title: "Screenshot failed", body: message)
            }
        }
    }

    private func restoreAppearance(_ appearance: AppearanceMode?, device: SimulatorDevice?) async {
        guard let appearance, let device else {
            return
        }

        try? await simctlService.setAppearance(device: device, appearance: appearance)
    }

    private func captureScreenshots(
        for appearances: [AppearanceMode],
        settings: AppSettings
    ) async throws -> [ScreenshotOutcome] {
        var outcomes: [ScreenshotOutcome] = []
        outcomes.reserveCapacity(appearances.count)

        for appearance in appearances {
            var variantSettings = settings
            variantSettings.appearanceMode = appearance
            let outcome = try await screenshotService.takeScreenshot(
                settings: variantSettings,
                filenameAppearanceVariant: appearance
            )
            outcomes.append(outcome)
        }

        return outcomes
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.outputFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputFolderPath = url.path
        }
    }

    func openOutputFolder() {
        let url = settings.outputFolderURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    func openSettingsWindow() {
        let window: NSWindow
        if let existingWindow = settingsWindow {
            window = existingWindow
        } else {
            let hostingController = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(self)
            )
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "SimDeck Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setFrameAutosaveName("SimDeckSettings")
            newWindow.center()
            settingsWindow = newWindow
            window = newWindow
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func userMessage(for error: Error) -> String {
        if let presentable = error as? UserPresentableError {
            return presentable.userMessage
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
