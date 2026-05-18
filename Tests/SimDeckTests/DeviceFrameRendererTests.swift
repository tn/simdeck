import AppKit
@testable import SimDeck
import XCTest

final class DeviceFrameRendererTests: XCTestCase {
    func testRendererIncreasesCanvasSize() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("simdeck_renderer_tests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let rawURL = temporaryDirectory.appendingPathComponent("raw.png")
        let outputURL = temporaryDirectory.appendingPathComponent("framed.png")

        try makeSampleScreenshot(size: CGSize(width: 390, height: 844), outputURL: rawURL)
        try DeviceFrameRenderer().render(rawScreenshot: rawURL, outputURL: outputURL, options: .default)

        let rawSize = try imagePixelSize(rawURL)
        let framedSize = try imagePixelSize(outputURL)

        XCTAssertGreaterThan(framedSize.width, rawSize.width)
        XCTAssertGreaterThan(framedSize.height, rawSize.height)
    }

    func testAutoFrameModeUsesSimulatorModel() {
        XCTAssertEqual(
            DeviceFrameMode.automaticMode(for: simulator(name: "iPhone 17 Pro", type: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro")),
            .genericIPhoneDynamicIsland
        )
        XCTAssertEqual(
            DeviceFrameMode.automaticMode(for: simulator(name: "iPad Pro 13-inch (M5)", type: "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB")),
            .genericIPad
        )
        XCTAssertEqual(
            DeviceFrameMode.automaticMode(for: simulator(name: "iPhone SE (3rd generation)", type: "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation")),
            .genericIPhoneSE
        )
        XCTAssertEqual(
            DeviceFrameMode.automaticMode(for: simulator(name: "iPhone 13", type: "com.apple.CoreSimulator.SimDeviceType.iPhone-13")),
            .genericIPhoneNotch
        )
    }

    private func makeSampleScreenshot(size: CGSize, outputURL: URL) throws {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        CGRect(origin: .zero, size: size).fill()
        NSColor.white.setFill()
        CGRect(x: 24, y: size.height - 96, width: size.width - 48, height: 48).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not create sample PNG")
            return
        }

        try png.write(to: outputURL)
    }

    private func imagePixelSize(_ url: URL) throws -> CGSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            XCTFail("Could not read image size")
            return .zero
        }

        return CGSize(width: width, height: height)
    }

    private func simulator(name: String, type: String) -> SimulatorDevice {
        SimulatorDevice(
            name: name,
            udid: UUID().uuidString,
            state: "Booted",
            isAvailable: true,
            runtime: "iOS 26 5",
            deviceTypeIdentifier: type
        )
    }
}
