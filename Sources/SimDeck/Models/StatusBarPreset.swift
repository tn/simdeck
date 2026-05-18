import Foundation

struct StatusBarPreset: Codable, Equatable {
    var time: String
    var batteryState: BatteryState
    var batteryLevel: Int
    var wifiBars: Int
    var cellularBars: Int
    var operatorName: String
    var dataNetwork: DataNetwork

    static let `default` = StatusBarPreset(
        time: "9:41",
        batteryState: .charged,
        batteryLevel: 100,
        wifiBars: 3,
        cellularBars: 4,
        operatorName: "",
        dataNetwork: .none
    )
}

enum BatteryState: String, Codable, CaseIterable, Identifiable {
    case charged
    case charging
    case discharging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .charged:
            return "Charged"
        case .charging:
            return "Charging"
        case .discharging:
            return "Discharging"
        }
    }
}

enum DataNetwork: String, Codable, CaseIterable, Identifiable {
    case none
    case wifi
    case threeG = "3g"
    case fourG = "4g"
    case lte
    case fiveG = "5g"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .wifi:
            return "Wi-Fi"
        case .threeG:
            return "3G"
        case .fourG:
            return "4G"
        case .lte:
            return "LTE"
        case .fiveG:
            return "5G"
        }
    }
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case doNotChange
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doNotChange:
            return "Do Not Change"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var simctlArgument: String? {
        switch self {
        case .doNotChange:
            return nil
        case .light:
            return "light"
        case .dark:
            return "dark"
        }
    }
}
