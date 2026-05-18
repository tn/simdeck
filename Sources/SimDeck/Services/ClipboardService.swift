import AppKit
import Foundation

enum ClipboardError: Error {
    case imageLoadFailed
}

final class ClipboardService {
    func copyImage(at url: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw ClipboardError.imageLoadFailed
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}
