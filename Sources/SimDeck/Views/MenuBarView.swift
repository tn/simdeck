import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Section("Pretty Simulator Shots") {
            Button {
                Task {
                    await appModel.takePrettyScreenshot()
                }
            } label: {
                Label("Take Screenshot", systemImage: "camera")
            }
            .disabled(appModel.isCapturing)

            Button {
                Task {
                    await appModel.takePrettyScreenshot(lightAndDark: true)
                }
            } label: {
                Label("Take Light + Dark", systemImage: "circle.lefthalf.filled")
            }
            .disabled(appModel.isCapturing)
        }

        if appModel.isCapturing {
            Text("Capturing...")
        }

        Section {
            Text("Device: \(appModel.deviceSummary)")
            Picker("Appearance", selection: $appModel.settings.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Toggle("Device Frame", isOn: $appModel.settings.deviceFrameEnabled)
            Picker("Frame", selection: $appModel.settings.frameOptions.mode) {
                ForEach(DeviceFrameMode.menuCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Picker("Frame Color", selection: $appModel.settings.frameOptions.frameColor) {
                ForEach(DeviceFrameColor.allCases) { color in
                    Text(color.displayName).tag(color)
                }
            }
            .disabled(!appModel.settings.deviceFrameEnabled)
        }

        if let warning = appModel.lastWarningMessage {
            Section("Warning") {
                Text(warning)
            }
        }

        if let error = appModel.lastErrorMessage {
            Section("Last Error") {
                Text(error)
            }
        }

        Section {
            Button {
                Task {
                    await appModel.refreshDevices()
                }
            } label: {
                Label("Refresh Devices", systemImage: "arrow.clockwise")
            }

            Button {
                appModel.openOutputFolder()
            } label: {
                Label("Open Output Folder", systemImage: "folder")
            }

            if let lastScreenshotURL = appModel.lastScreenshotURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([lastScreenshotURL])
                } label: {
                    Label("Reveal Last Screenshot", systemImage: "magnifyingglass")
                }
            }
        }

        Section {
            Button {
                appModel.openSettingsWindow()
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                appModel.quit()
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
