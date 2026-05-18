import Foundation

enum FileNameBuilder {
    static func defaultOutputFolder() -> URL {
        if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktop.appendingPathComponent("iOS Simulator Screenshots", isDirectory: true)
        }

        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent("iOS Simulator Screenshots", isDirectory: true)
    }

    static func outputURL(
        in folder: URL,
        pattern: String,
        simulator: SimulatorDevice,
        framed: Bool,
        appearanceVariant: AppearanceMode? = nil
    ) -> URL {
        let device = sanitize(simulator.name)
        let timestamp = timestampString()
        let basePattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppSettings.default.filenamePattern
            : pattern

        var filename = basePattern
            .replacingOccurrences(of: "{device}", with: device)
            .replacingOccurrences(of: "{yyyy-MM-dd_HH-mm-ss}", with: timestamp)
            .replacingOccurrences(of: "{appearance}", with: appearanceVariant?.filenameComponent ?? "system")
            .replacingOccurrences(of: "{app}", with: "app")
            .replacingOccurrences(of: "{screen}", with: "screen")

        if !filename.lowercased().hasSuffix(".png") {
            filename += ".png"
        }

        if let appearanceVariant, !basePattern.contains("{appearance}") {
            filename = insertSuffix("_\(appearanceVariant.filenameComponent)", in: filename)
        }

        if framed {
            filename = insertSuffix("_framed", in: filename)
        }

        return uniqueURL(folder.appendingPathComponent(filename))
    }

    static func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = input.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return collapsed.isEmpty ? "Simulator" : collapsed
    }

    private static func insertSuffix(_ suffix: String, in filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension
        let basename = url.deletingPathExtension().lastPathComponent
        if basename.contains(suffix.trimmingCharacters(in: CharacterSet(charactersIn: "_"))) {
            return filename
        }
        return ext.isEmpty ? "\(basename)\(suffix)" : "\(basename)\(suffix).\(ext)"
    }

    private static func uniqueURL(_ url: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let basename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var index = 2
        while true {
            let filename = ext.isEmpty ? "\(basename)-\(index)" : "\(basename)-\(index).\(ext)"
            let candidate = directory.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

extension AppearanceMode {
    var filenameComponent: String {
        switch self {
        case .doNotChange:
            return "system"
        case .light:
            return "light"
        case .dark:
            return "dark"
        }
    }
}
