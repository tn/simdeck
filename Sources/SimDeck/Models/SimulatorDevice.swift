import Foundation

struct SimulatorDevice: Identifiable, Codable, Equatable {
    let name: String
    let udid: String
    let state: String
    let runtime: String?
    let deviceTypeIdentifier: String?

    var id: String { udid }
    var isBooted: Bool { state == "Booted" }

    var menuTitle: String {
        let stateSuffix = isBooted ? "Booted" : state
        if let runtime {
            return "\(name) - \(runtime) - \(stateSuffix)"
        }
        return "\(name) - \(stateSuffix)"
    }
}

struct SimctlDevicesResponse: Decodable {
    let devices: [String: [SimctlDeviceDTO]]
}

struct SimctlDeviceDTO: Decodable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool
    let deviceTypeIdentifier: String?
}
