import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            statusBarSettings
                .tabItem {
                    Label("Status Bar", systemImage: "wifi")
                }

            appearanceSettings
                .tabItem {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }

            frameSettings
                .tabItem {
                    Label("Device Frame", systemImage: "iphone")
                }
        }
        .frame(width: 540, height: 420)
        .padding(20)
        .task {
            await appModel.refreshDevices()
        }
    }

    private var generalSettings: some View {
        Form {
            Section {
                HStack {
                    Text(appModel.settings.outputFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Choose...") {
                        appModel.chooseOutputFolder()
                    }
                }

                TextField("Filename pattern", text: $appModel.settings.filenamePattern)
                    .textFieldStyle(.roundedBorder)

                Toggle("Reveal in Finder after screenshot", isOn: $appModel.settings.revealInFinderAfterScreenshot)
                Toggle("Copy to clipboard after screenshot", isOn: $appModel.settings.copyToClipboardAfterScreenshot)
                Toggle("Show notification after screenshot", isOn: $appModel.settings.showNotificationAfterScreenshot)
            } header: {
                Text("Output")
            }

            Section {
                Toggle("Use booted simulator automatically", isOn: $appModel.settings.useBootedSimulatorAutomatically)

                Picker("Selected device", selection: selectedDeviceBinding) {
                    Text("None").tag(Optional<String>.none)
                    ForEach(appModel.devices) { device in
                        Text(device.menuTitle).tag(Optional(device.udid))
                    }
                }
                .disabled(appModel.settings.useBootedSimulatorAutomatically)
            } header: {
                Text("Simulator")
            }
        }
        .formStyle(.grouped)
    }

    private var statusBarSettings: some View {
        Form {
            Toggle("Enable pretty status bar", isOn: $appModel.settings.prettyStatusBarEnabled)

            TextField("Time", text: $appModel.settings.statusBarPreset.time)
                .textFieldStyle(.roundedBorder)

            Picker("Battery state", selection: $appModel.settings.statusBarPreset.batteryState) {
                ForEach(BatteryState.allCases) { state in
                    Text(state.displayName).tag(state)
                }
            }

            Stepper(
                "Battery level: \(appModel.settings.statusBarPreset.batteryLevel)%",
                value: $appModel.settings.statusBarPreset.batteryLevel,
                in: 0...100
            )

            Stepper(
                "Wi-Fi bars: \(appModel.settings.statusBarPreset.wifiBars)",
                value: $appModel.settings.statusBarPreset.wifiBars,
                in: 0...3
            )

            Stepper(
                "Cellular bars: \(appModel.settings.statusBarPreset.cellularBars)",
                value: $appModel.settings.statusBarPreset.cellularBars,
                in: 0...4
            )

            TextField("Operator name (optional)", text: $appModel.settings.statusBarPreset.operatorName)
                .textFieldStyle(.roundedBorder)

            Picker("Data network", selection: $appModel.settings.statusBarPreset.dataNetwork) {
                ForEach(DataNetwork.allCases) { network in
                    Text(network.displayName).tag(network)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceSettings: some View {
        Form {
            Picker("Before screenshot", selection: $appModel.settings.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Text("Use the menu bar Light + Dark action to capture both variants at once.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var frameSettings: some View {
        Form {
            Toggle("Render device frame", isOn: $appModel.settings.deviceFrameEnabled)

            Picker("Frame style", selection: $appModel.settings.frameOptions.mode) {
                ForEach(DeviceFrameMode.settingsCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(!appModel.settings.deviceFrameEnabled)

            Picker("Frame color", selection: $appModel.settings.frameOptions.frameColor) {
                ForEach(DeviceFrameColor.allCases) { color in
                    HStack {
                        Circle()
                            .fill(Color(nsColor: color.swatchColor))
                            .frame(width: 10, height: 10)
                        Text(color.displayName)
                    }
                    .tag(color)
                }
            }
            .disabled(!appModel.settings.deviceFrameEnabled)

            Picker("Background", selection: $appModel.settings.frameOptions.backgroundMode) {
                ForEach(FrameBackgroundMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(!appModel.settings.deviceFrameEnabled)

            if appModel.settings.frameOptions.backgroundMode == .solid {
                ColorPicker("Solid color", selection: colorBinding(\.solidColor))
            }

            if appModel.settings.frameOptions.backgroundMode == .gradient {
                ColorPicker("Gradient top", selection: colorBinding(\.gradientTopColor))
                ColorPicker("Gradient bottom", selection: colorBinding(\.gradientBottomColor))
            }

            Slider(
                value: $appModel.settings.frameOptions.padding,
                in: 24...240,
                step: 8
            ) {
                Text("Padding")
            } minimumValueLabel: {
                Text("24")
            } maximumValueLabel: {
                Text("240")
            }
            Text("Padding: \(Int(appModel.settings.frameOptions.padding)) px")
                .foregroundStyle(.secondary)

            Toggle("Soft shadow", isOn: $appModel.settings.frameOptions.shadowEnabled)

            Picker("Output scale", selection: $appModel.settings.frameOptions.outputScale) {
                Text("1x").tag(1.0)
                Text("2x").tag(2.0)
                Text("3x").tag(3.0)
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }

    private var selectedDeviceBinding: Binding<String?> {
        Binding {
            appModel.settings.selectedDeviceUDID
        } set: { newValue in
            appModel.settings.selectedDeviceUDID = newValue
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<DeviceFrameOptionsCodable, CodableColor>) -> Binding<Color> {
        Binding {
            Color(nsColor: appModel.settings.frameOptions[keyPath: keyPath].nsColor)
        } set: { newValue in
            appModel.settings.frameOptions[keyPath: keyPath] = CodableColor(nsColor: NSColor(newValue))
        }
    }
}
