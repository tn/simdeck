import AppKit
import Foundation

struct DeviceFrameOptionsCodable: Codable, Equatable {
    var mode: DeviceFrameMode
    var frameColor: DeviceFrameColor
    var backgroundMode: FrameBackgroundMode
    var padding: Double
    var shadowEnabled: Bool
    var outputScale: Double
    var solidColor: CodableColor
    var gradientTopColor: CodableColor
    var gradientBottomColor: CodableColor

    static let `default` = DeviceFrameOptionsCodable(
        mode: .auto,
        frameColor: .graphite,
        backgroundMode: .transparent,
        padding: 120,
        shadowEnabled: true,
        outputScale: 1,
        solidColor: CodableColor(nsColor: NSColor.windowBackgroundColor),
        gradientTopColor: CodableColor(nsColor: NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)),
        gradientBottomColor: CodableColor(nsColor: NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.96, alpha: 1.0))
    )

    init(
        mode: DeviceFrameMode,
        frameColor: DeviceFrameColor,
        backgroundMode: FrameBackgroundMode,
        padding: Double,
        shadowEnabled: Bool,
        outputScale: Double,
        solidColor: CodableColor,
        gradientTopColor: CodableColor,
        gradientBottomColor: CodableColor
    ) {
        self.mode = mode
        self.frameColor = frameColor
        self.backgroundMode = backgroundMode
        self.padding = padding
        self.shadowEnabled = shadowEnabled
        self.outputScale = outputScale
        self.solidColor = solidColor
        self.gradientTopColor = gradientTopColor
        self.gradientBottomColor = gradientBottomColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DeviceFrameOptionsCodable.default
        self.mode = try container.decodeIfPresent(DeviceFrameMode.self, forKey: .mode) ?? defaults.mode
        self.frameColor = try container.decodeIfPresent(DeviceFrameColor.self, forKey: .frameColor) ?? defaults.frameColor
        self.backgroundMode = try container.decodeIfPresent(FrameBackgroundMode.self, forKey: .backgroundMode) ?? defaults.backgroundMode
        self.padding = try container.decodeIfPresent(Double.self, forKey: .padding) ?? defaults.padding
        self.shadowEnabled = try container.decodeIfPresent(Bool.self, forKey: .shadowEnabled) ?? defaults.shadowEnabled
        self.outputScale = try container.decodeIfPresent(Double.self, forKey: .outputScale) ?? defaults.outputScale
        self.solidColor = try container.decodeIfPresent(CodableColor.self, forKey: .solidColor) ?? defaults.solidColor
        self.gradientTopColor = try container.decodeIfPresent(CodableColor.self, forKey: .gradientTopColor) ?? defaults.gradientTopColor
        self.gradientBottomColor = try container.decodeIfPresent(CodableColor.self, forKey: .gradientBottomColor) ?? defaults.gradientBottomColor
    }
}

enum DeviceFrameMode: String, Codable, CaseIterable, Identifiable {
    case auto
    case genericIPhoneDynamicIsland
    case genericIPhoneNotch
    case genericIPhoneSE
    case genericIPad

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case Self.auto.rawValue:
            self = .auto
        case Self.genericIPhoneDynamicIsland.rawValue:
            self = .genericIPhoneDynamicIsland
        case Self.genericIPhoneNotch.rawValue:
            self = .genericIPhoneNotch
        case Self.genericIPhoneSE.rawValue:
            self = .genericIPhoneSE
        case Self.genericIPad.rawValue:
            self = .genericIPad
        default:
            self = .auto
        }
    }

    static var menuCases: [DeviceFrameMode] {
        [.auto, .genericIPhoneDynamicIsland, .genericIPhoneNotch]
    }

    static var settingsCases: [DeviceFrameMode] {
        menuCases
    }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto (Current Device)"
        case .genericIPhoneDynamicIsland:
            return "iPhone Dynamic Island"
        case .genericIPhoneNotch:
            return "iPhone Notch"
        case .genericIPhoneSE:
            return "iPhone SE"
        case .genericIPad:
            return "iPad"
        }
    }
}

extension DeviceFrameMode {
    static func automaticMode(for simulator: SimulatorDevice?) -> DeviceFrameMode {
        let deviceText = [
            simulator?.name,
            simulator?.deviceTypeIdentifier
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        guard !deviceText.isEmpty else {
            return .genericIPhoneDynamicIsland
        }

        if deviceText.contains("ipad") {
            return .genericIPad
        }

        if deviceText.contains("iphone-se")
            || deviceText.contains("iphone se")
            || deviceText.contains("iphone-8")
            || deviceText.contains("iphone 8")
            || deviceText.contains("iphone-7")
            || deviceText.contains("iphone 7")
            || deviceText.contains("iphone-6")
            || deviceText.contains("iphone 6") {
            return .genericIPhoneSE
        }

        if deviceText.contains("iphone-16e")
            || deviceText.contains("iphone 16e")
            || deviceText.contains("iphone-17e")
            || deviceText.contains("iphone 17e") {
            return .genericIPhoneNotch
        }

        if deviceText.contains("iphone-14-pro")
            || deviceText.contains("iphone 14 pro")
            || deviceText.contains("iphone-15")
            || deviceText.contains("iphone 15")
            || deviceText.contains("iphone-16")
            || deviceText.contains("iphone 16")
            || deviceText.contains("iphone-17")
            || deviceText.contains("iphone 17")
            || deviceText.contains("iphone-air")
            || deviceText.contains("iphone air") {
            return .genericIPhoneDynamicIsland
        }

        if deviceText.contains("iphone-x")
            || deviceText.contains("iphone x")
            || deviceText.contains("iphone-11")
            || deviceText.contains("iphone 11")
            || deviceText.contains("iphone-12")
            || deviceText.contains("iphone 12")
            || deviceText.contains("iphone-13")
            || deviceText.contains("iphone 13")
            || deviceText.contains("iphone-14")
            || deviceText.contains("iphone 14") {
            return .genericIPhoneNotch
        }

        return .genericIPhoneDynamicIsland
    }
}

enum DeviceFrameColor: String, Codable, CaseIterable, Identifiable {
    case graphite
    case silver
    case deepBlue
    case cosmicOrange
    case blackTitanium
    case naturalTitanium
    case whiteTitanium
    case desertTitanium
    case ultramarine
    case teal
    case pink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .graphite:
            return "Graphite"
        case .silver:
            return "Silver"
        case .deepBlue:
            return "Deep Blue"
        case .cosmicOrange:
            return "Cosmic Orange"
        case .blackTitanium:
            return "Black Titanium"
        case .naturalTitanium:
            return "Natural Titanium"
        case .whiteTitanium:
            return "White Titanium"
        case .desertTitanium:
            return "Desert Titanium"
        case .ultramarine:
            return "Ultramarine"
        case .teal:
            return "Teal"
        case .pink:
            return "Pink"
        }
    }

    var swatchColor: NSColor {
        palette.mid
    }

    var palette: DeviceFrameColorPalette {
        switch self {
        case .graphite:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.42, green: 0.43, blue: 0.42, alpha: 1),
                mid: NSColor(srgbRed: 0.17, green: 0.18, blue: 0.18, alpha: 1),
                dark: NSColor(srgbRed: 0.035, green: 0.036, blue: 0.038, alpha: 1)
            )
        case .silver:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.94, green: 0.93, blue: 0.89, alpha: 1),
                mid: NSColor(srgbRed: 0.72, green: 0.71, blue: 0.67, alpha: 1),
                dark: NSColor(srgbRed: 0.23, green: 0.23, blue: 0.22, alpha: 1)
            )
        case .deepBlue:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.27, green: 0.34, blue: 0.47, alpha: 1),
                mid: NSColor(srgbRed: 0.08, green: 0.12, blue: 0.22, alpha: 1),
                dark: NSColor(srgbRed: 0.018, green: 0.025, blue: 0.05, alpha: 1)
            )
        case .cosmicOrange:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.95, green: 0.55, blue: 0.30, alpha: 1),
                mid: NSColor(srgbRed: 0.70, green: 0.28, blue: 0.12, alpha: 1),
                dark: NSColor(srgbRed: 0.20, green: 0.07, blue: 0.03, alpha: 1)
            )
        case .blackTitanium:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.31, green: 0.31, blue: 0.30, alpha: 1),
                mid: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1),
                dark: NSColor(srgbRed: 0.018, green: 0.018, blue: 0.018, alpha: 1)
            )
        case .naturalTitanium:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.78, green: 0.74, blue: 0.67, alpha: 1),
                mid: NSColor(srgbRed: 0.49, green: 0.45, blue: 0.39, alpha: 1),
                dark: NSColor(srgbRed: 0.19, green: 0.17, blue: 0.15, alpha: 1)
            )
        case .whiteTitanium:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.95, green: 0.93, blue: 0.88, alpha: 1),
                mid: NSColor(srgbRed: 0.77, green: 0.74, blue: 0.68, alpha: 1),
                dark: NSColor(srgbRed: 0.28, green: 0.27, blue: 0.25, alpha: 1)
            )
        case .desertTitanium:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.86, green: 0.69, blue: 0.54, alpha: 1),
                mid: NSColor(srgbRed: 0.58, green: 0.39, blue: 0.25, alpha: 1),
                dark: NSColor(srgbRed: 0.23, green: 0.12, blue: 0.07, alpha: 1)
            )
        case .ultramarine:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.38, green: 0.48, blue: 0.86, alpha: 1),
                mid: NSColor(srgbRed: 0.16, green: 0.24, blue: 0.56, alpha: 1),
                dark: NSColor(srgbRed: 0.04, green: 0.07, blue: 0.20, alpha: 1)
            )
        case .teal:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.43, green: 0.74, blue: 0.68, alpha: 1),
                mid: NSColor(srgbRed: 0.12, green: 0.45, blue: 0.42, alpha: 1),
                dark: NSColor(srgbRed: 0.03, green: 0.15, blue: 0.14, alpha: 1)
            )
        case .pink:
            return DeviceFrameColorPalette(
                light: NSColor(srgbRed: 0.96, green: 0.64, blue: 0.76, alpha: 1),
                mid: NSColor(srgbRed: 0.70, green: 0.30, blue: 0.44, alpha: 1),
                dark: NSColor(srgbRed: 0.22, green: 0.07, blue: 0.12, alpha: 1)
            )
        }
    }
}

struct DeviceFrameColorPalette {
    let light: NSColor
    let mid: NSColor
    let dark: NSColor
}

enum FrameBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case transparent
    case solid
    case gradient

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transparent:
            return "Transparent"
        case .solid:
            return "Solid"
        case .gradient:
            return "Gradient"
        }
    }
}

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.red = Double(color.redComponent)
        self.green = Double(color.greenComponent)
        self.blue = Double(color.blueComponent)
        self.alpha = Double(color.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}
