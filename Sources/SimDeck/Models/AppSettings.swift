import Foundation

struct AppSettings: Codable, Equatable {
    var outputFolderPath: String
    var filenamePattern: String
    var revealInFinderAfterScreenshot: Bool
    var copyToClipboardAfterScreenshot: Bool
    var showNotificationAfterScreenshot: Bool
    var useBootedSimulatorAutomatically: Bool
    var selectedDeviceUDID: String?

    var prettyStatusBarEnabled: Bool
    var statusBarPreset: StatusBarPreset
    var appearanceMode: AppearanceMode

    var deviceFrameEnabled: Bool
    var frameOptions: DeviceFrameOptionsCodable

    static let `default` = AppSettings(
        outputFolderPath: FileNameBuilder.defaultOutputFolder().path,
        filenamePattern: "screenshot_{device}_{yyyy-MM-dd_HH-mm-ss}.png",
        revealInFinderAfterScreenshot: true,
        copyToClipboardAfterScreenshot: false,
        showNotificationAfterScreenshot: true,
        useBootedSimulatorAutomatically: true,
        selectedDeviceUDID: nil,
        prettyStatusBarEnabled: true,
        statusBarPreset: .default,
        appearanceMode: .doNotChange,
        deviceFrameEnabled: false,
        frameOptions: .default
    )

    init(
        outputFolderPath: String,
        filenamePattern: String,
        revealInFinderAfterScreenshot: Bool,
        copyToClipboardAfterScreenshot: Bool,
        showNotificationAfterScreenshot: Bool,
        useBootedSimulatorAutomatically: Bool,
        selectedDeviceUDID: String?,
        prettyStatusBarEnabled: Bool,
        statusBarPreset: StatusBarPreset,
        appearanceMode: AppearanceMode,
        deviceFrameEnabled: Bool,
        frameOptions: DeviceFrameOptionsCodable
    ) {
        self.outputFolderPath = outputFolderPath
        self.filenamePattern = filenamePattern
        self.revealInFinderAfterScreenshot = revealInFinderAfterScreenshot
        self.copyToClipboardAfterScreenshot = copyToClipboardAfterScreenshot
        self.showNotificationAfterScreenshot = showNotificationAfterScreenshot
        self.useBootedSimulatorAutomatically = useBootedSimulatorAutomatically
        self.selectedDeviceUDID = selectedDeviceUDID
        self.prettyStatusBarEnabled = prettyStatusBarEnabled
        self.statusBarPreset = statusBarPreset
        self.appearanceMode = appearanceMode
        self.deviceFrameEnabled = deviceFrameEnabled
        self.frameOptions = frameOptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default
        self.outputFolderPath = try container.decodeIfPresent(String.self, forKey: .outputFolderPath) ?? defaults.outputFolderPath
        self.filenamePattern = try container.decodeIfPresent(String.self, forKey: .filenamePattern) ?? defaults.filenamePattern
        self.revealInFinderAfterScreenshot = try container.decodeIfPresent(Bool.self, forKey: .revealInFinderAfterScreenshot) ?? defaults.revealInFinderAfterScreenshot
        self.copyToClipboardAfterScreenshot = try container.decodeIfPresent(Bool.self, forKey: .copyToClipboardAfterScreenshot) ?? defaults.copyToClipboardAfterScreenshot
        self.showNotificationAfterScreenshot = try container.decodeIfPresent(Bool.self, forKey: .showNotificationAfterScreenshot) ?? defaults.showNotificationAfterScreenshot
        self.useBootedSimulatorAutomatically = try container.decodeIfPresent(Bool.self, forKey: .useBootedSimulatorAutomatically) ?? defaults.useBootedSimulatorAutomatically
        self.selectedDeviceUDID = try container.decodeIfPresent(String.self, forKey: .selectedDeviceUDID)
        self.prettyStatusBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .prettyStatusBarEnabled) ?? defaults.prettyStatusBarEnabled
        self.statusBarPreset = try container.decodeIfPresent(StatusBarPreset.self, forKey: .statusBarPreset) ?? defaults.statusBarPreset
        self.appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? defaults.appearanceMode
        self.deviceFrameEnabled = try container.decodeIfPresent(Bool.self, forKey: .deviceFrameEnabled) ?? defaults.deviceFrameEnabled
        self.frameOptions = try container.decodeIfPresent(DeviceFrameOptionsCodable.self, forKey: .frameOptions) ?? defaults.frameOptions
    }

    var outputFolderURL: URL {
        URL(fileURLWithPath: (outputFolderPath as NSString).expandingTildeInPath, isDirectory: true)
    }
}
