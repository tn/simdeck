import AppKit
import Foundation

enum DeviceFrameRendererError: Error {
    case couldNotLoadImage
    case couldNotExportPNG
}

final class DeviceFrameRenderer {
    func render(
        rawScreenshot: URL,
        outputURL: URL,
        options: DeviceFrameOptionsCodable,
        simulator: SimulatorDevice? = nil
    ) throws {
        guard let screenshot = NSImage(contentsOf: rawScreenshot),
              let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DeviceFrameRendererError.couldNotLoadImage
        }

        let profile = DeviceFrameProfile.resolve(mode: options.mode, simulator: simulator)
        let framePalette = options.frameColor.palette
        let outputScale = max(1.0, CGFloat(options.outputScale))
        let screenshotSize = CGSize(width: CGFloat(cgImage.width) * outputScale, height: CGFloat(cgImage.height) * outputScale)
        let shortestSide = min(screenshotSize.width, screenshotSize.height)
        let railWidth = max(profile.minimumRailWidth * outputScale, shortestSide * profile.railWidthRatio)
        let screenInsets = profile.screenInsets(for: shortestSide, scale: outputScale)
        let padding = max(0, CGFloat(options.padding) * outputScale)

        let outerRect = CGRect(
            x: padding,
            y: padding,
            width: screenshotSize.width + screenInsets.left + screenInsets.right + railWidth * 2,
            height: screenshotSize.height + screenInsets.top + screenInsets.bottom + railWidth * 2
        )
        let bodyRect = outerRect.insetBy(dx: railWidth, dy: railWidth)
        let screenRect = CGRect(
            x: bodyRect.minX + screenInsets.left,
            y: bodyRect.minY + screenInsets.bottom,
            width: screenshotSize.width,
            height: screenshotSize.height
        )
        let canvasSize = CGSize(width: outerRect.width + padding * 2, height: outerRect.height + padding * 2)

        let pixelWidth = Int(canvasSize.width.rounded(.up))
        let pixelHeight = Int(canvasSize.height.rounded(.up))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw DeviceFrameRendererError.couldNotExportPNG
        }
        bitmap.size = canvasSize

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw DeviceFrameRendererError.couldNotExportPNG
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        defer {
            NSGraphicsContext.current = previousContext
        }

        context.imageInterpolation = .high
        context.cgContext.setShouldAntialias(true)
        drawBackground(in: CGRect(origin: .zero, size: canvasSize), options: options, context: context.cgContext)
        drawDeviceShell(
            profile: profile,
            outerRect: outerRect,
            bodyRect: bodyRect,
            screenRect: screenRect,
            railWidth: railWidth,
            framePalette: framePalette,
            shadowEnabled: options.shadowEnabled,
            scale: outputScale
        )
        drawScreenshot(screenshot, in: screenRect, profile: profile, scale: outputScale)
        drawHardwareDetails(profile: profile, bodyRect: bodyRect, screenRect: screenRect, screenInsets: screenInsets, scale: outputScale)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw DeviceFrameRendererError.couldNotExportPNG
        }

        try png.write(to: outputURL, options: .atomic)
    }

    private func drawBackground(in rect: CGRect, options: DeviceFrameOptionsCodable, context: CGContext) {
        switch options.backgroundMode {
        case .transparent:
            context.clear(rect)
        case .solid:
            options.solidColor.nsColor.setFill()
            rect.fill()
        case .gradient:
            let gradient = NSGradient(
                starting: options.gradientBottomColor.nsColor,
                ending: options.gradientTopColor.nsColor
            )
            gradient?.draw(in: rect, angle: 90)
        }
    }

    private func drawDeviceShell(
        profile: DeviceFrameProfile,
        outerRect: CGRect,
        bodyRect: CGRect,
        screenRect: CGRect,
        railWidth: CGFloat,
        framePalette: DeviceFrameColorPalette,
        shadowEnabled: Bool,
        scale: CGFloat
    ) {
        let screenRadius = profile.screenRadius(for: screenRect, scale: scale)
        let bodyRadius = profile.synchronizedRadius(
            from: screenRadius,
            innerRect: screenRect,
            outerRect: bodyRect
        )
        let outerRadius = profile.synchronizedRadius(
            from: screenRadius,
            innerRect: screenRect,
            outerRect: outerRect
        )

        let outerPath = continuousRoundedRectPath(in: outerRect, radius: outerRadius)
        let bodyPath = continuousRoundedRectPath(in: bodyRect, radius: bodyRadius)

        NSGraphicsContext.saveGraphicsState()
        if shadowEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(profile.shadowAlpha)
            shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
            shadow.shadowBlurRadius = 44 * scale
            shadow.set()
        }
        if let shellGradient = NSGradient(colors: [
            framePalette.light.withAlphaComponent(0.55),
            framePalette.dark,
            framePalette.mid.withAlphaComponent(0.70)
        ]) {
            shellGradient.draw(in: outerPath, angle: -18)
        } else {
            framePalette.mid.setFill()
            outerPath.fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        let bodyColor = framePalette.dark.blended(withFraction: 0.74, of: .black) ?? .black
        bodyColor.setFill()
        bodyPath.fill()

        let outerStrokeInset = 0.75 * scale
        let outerStroke = continuousRoundedRectPath(
            in: outerRect.insetBy(dx: outerStrokeInset, dy: outerStrokeInset),
            radius: max(0, outerRadius - outerStrokeInset)
        )
        framePalette.light.withAlphaComponent(0.30).setStroke()
        outerStroke.lineWidth = max(1, scale)
        outerStroke.stroke()

        let lipInset = max(4 * scale, railWidth * 0.55)
        let screenLipRect = screenRect.insetBy(dx: -lipInset, dy: -lipInset)
        let screenLipRadius = screenRadius + lipInset
        let screenLip = continuousRoundedRectPath(in: screenLipRect, radius: screenLipRadius)
        NSColor.black.withAlphaComponent(0.92).setFill()
        screenLip.fill()
    }

    private func drawScreenshot(_ screenshot: NSImage, in screenRect: CGRect, profile: DeviceFrameProfile, scale: CGFloat) {
        let screenRadius = profile.screenRadius(for: screenRect, scale: scale)
        NSGraphicsContext.saveGraphicsState()
        continuousRoundedRectPath(in: screenRect, radius: screenRadius).addClip()
        screenshot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let innerStrokeInset = 0.5 * scale
        let innerStroke = continuousRoundedRectPath(
            in: screenRect.insetBy(dx: innerStrokeInset, dy: innerStrokeInset),
            radius: max(0, screenRadius - innerStrokeInset)
        )
        NSColor.white.withAlphaComponent(0.10).setStroke()
        innerStroke.lineWidth = max(1, scale)
        innerStroke.stroke()
    }

    private func drawHardwareDetails(
        profile: DeviceFrameProfile,
        bodyRect: CGRect,
        screenRect: CGRect,
        screenInsets: NSEdgeInsets,
        scale: CGFloat
    ) {
        switch profile.hardware {
        case .fullScreen:
            break

        case .speaker:
            drawSpeaker(in: bodyRect, screenInsets: screenInsets, scale: scale)

        case .homeButton:
            drawSpeaker(in: bodyRect, screenInsets: screenInsets, scale: scale)
            let diameter = max(42 * scale, min(bodyRect.width, bodyRect.height) * 0.055)
            let buttonRect = CGRect(
                x: bodyRect.midX - diameter / 2,
                y: bodyRect.minY + max(18 * scale, screenInsets.bottom * 0.28),
                width: diameter,
                height: diameter
            )
            NSColor(white: 0.18, alpha: 1).setStroke()
            let homePath = NSBezierPath(ovalIn: buttonRect)
            homePath.lineWidth = max(2, 2 * scale)
            homePath.stroke()

        case .iPad:
            let diameter = max(7 * scale, min(bodyRect.width, bodyRect.height) * 0.006)
            let cameraRect = CGRect(
                x: bodyRect.midX - diameter / 2,
                y: screenRect.maxY + max(8 * scale, screenInsets.top * 0.36),
                width: diameter,
                height: diameter
            )
            NSColor(white: 0.11, alpha: 1).setFill()
            NSBezierPath(ovalIn: cameraRect).fill()
        }
    }

    private func drawSpeaker(in bodyRect: CGRect, screenInsets: NSEdgeInsets, scale: CGFloat) {
        let speakerWidth = max(60 * scale, bodyRect.width * 0.10)
        let speakerHeight = max(6 * scale, screenInsets.top * 0.12)
        let speakerRect = CGRect(
            x: bodyRect.midX - speakerWidth / 2,
            y: bodyRect.maxY - max(18 * scale, screenInsets.top * 0.34),
            width: speakerWidth,
            height: speakerHeight
        )
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: speakerRect,
            xRadius: speakerHeight / 2,
            yRadius: speakerHeight / 2
        ).fill()
    }

    private func continuousRoundedRectPath(in rect: CGRect, radius: CGFloat) -> NSBezierPath {
        let radius = min(max(0, radius), min(rect.width, rect.height) / 2)
        guard radius > 0 else {
            return NSBezierPath(rect: rect)
        }

        let path = NSBezierPath()
        let steps = 22
        let exponent: CGFloat = 3.05
        let power = 2 / exponent

        func eased(_ value: CGFloat) -> CGFloat {
            pow(max(0, min(1, value)), power)
        }

        func addCornerPoints(_ point: (CGFloat) -> CGPoint) {
            for step in 1...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                path.line(to: point(progress * .pi / 2))
            }
        }

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.line(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        addCornerPoints { angle in
            CGPoint(
                x: rect.maxX - radius + radius * eased(sin(angle)),
                y: rect.maxY - radius + radius * eased(cos(angle))
            )
        }
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY + radius))
        addCornerPoints { angle in
            CGPoint(
                x: rect.maxX - radius + radius * eased(cos(angle)),
                y: rect.minY + radius - radius * eased(sin(angle))
            )
        }
        path.line(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        addCornerPoints { angle in
            CGPoint(
                x: rect.minX + radius - radius * eased(sin(angle)),
                y: rect.minY + radius - radius * eased(cos(angle))
            )
        }
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        addCornerPoints { angle in
            CGPoint(
                x: rect.minX + radius - radius * eased(cos(angle)),
                y: rect.maxY - radius + radius * eased(sin(angle))
            )
        }
        path.close()
        return path
    }
}

private enum DeviceFrameHardware {
    case fullScreen
    case homeButton
    case speaker
    case iPad
}

private struct DeviceFrameProfile {
    let hardware: DeviceFrameHardware
    let railWidthRatio: CGFloat
    let minimumRailWidth: CGFloat
    let sideInsetRatio: CGFloat
    let topInsetRatio: CGFloat
    let bottomInsetRatio: CGFloat
    let minimumSideInset: CGFloat
    let minimumTopInset: CGFloat
    let minimumBottomInset: CGFloat
    let outerRadiusRatio: CGFloat
    let bodyRadiusRatio: CGFloat
    let screenRadiusRatio: CGFloat
    let minimumOuterRadius: CGFloat
    let minimumBodyRadius: CGFloat
    let minimumScreenRadius: CGFloat
    let shadowAlpha: CGFloat

    static func resolve(mode: DeviceFrameMode, simulator: SimulatorDevice?) -> DeviceFrameProfile {
        switch mode {
        case .auto:
            return resolve(mode: DeviceFrameMode.automaticMode(for: simulator), simulator: simulator)
        case .genericIPhoneDynamicIsland, .genericIPhoneNotch:
            return modernIPhone
        case .genericIPhone:
            return genericIPhone
        case .genericIPhoneSE:
            return classicIPhone
        case .genericIPad:
            return iPad
        case .off:
            return modernIPhone
        }
    }

    func screenInsets(for shortestSide: CGFloat, scale: CGFloat) -> NSEdgeInsets {
        NSEdgeInsets(
            top: max(minimumTopInset * scale, shortestSide * topInsetRatio),
            left: max(minimumSideInset * scale, shortestSide * sideInsetRatio),
            bottom: max(minimumBottomInset * scale, shortestSide * bottomInsetRatio),
            right: max(minimumSideInset * scale, shortestSide * sideInsetRatio)
        )
    }

    func screenRadius(for screenRect: CGRect, scale: CGFloat) -> CGFloat {
        let rawRadius = max(minimumScreenRadius * scale, min(screenRect.width, screenRect.height) * screenRadiusRatio)
        return min(rawRadius, min(screenRect.width, screenRect.height) * 0.46)
    }

    func synchronizedRadius(from innerRadius: CGFloat, innerRect: CGRect, outerRect: CGRect) -> CGFloat {
        let leftInset = innerRect.minX - outerRect.minX
        let rightInset = outerRect.maxX - innerRect.maxX
        let topInset = outerRect.maxY - innerRect.maxY
        let bottomInset = innerRect.minY - outerRect.minY
        let horizontalInset = (leftInset + rightInset) / 2
        let verticalInset = (topInset + bottomInset) / 2
        let cornerInset = max(0, (horizontalInset + verticalInset) / 2)
        let rawRadius = innerRadius + cornerInset
        return min(rawRadius, min(outerRect.width, outerRect.height) * 0.48)
    }

    private static let modernIPhone = DeviceFrameProfile(
        hardware: .fullScreen,
        railWidthRatio: 0.008,
        minimumRailWidth: 6,
        sideInsetRatio: 0.026,
        topInsetRatio: 0.025,
        bottomInsetRatio: 0.025,
        minimumSideInset: 22,
        minimumTopInset: 21,
        minimumBottomInset: 21,
        outerRadiusRatio: 0.150,
        bodyRadiusRatio: 0.138,
        screenRadiusRatio: 0.205,
        minimumOuterRadius: 114,
        minimumBodyRadius: 102,
        minimumScreenRadius: 176,
        shadowAlpha: 0.42
    )

    private static let genericIPhone = DeviceFrameProfile(
        hardware: .speaker,
        railWidthRatio: 0.010,
        minimumRailWidth: 8,
        sideInsetRatio: 0.026,
        topInsetRatio: 0.055,
        bottomInsetRatio: 0.026,
        minimumSideInset: 20,
        minimumTopInset: 48,
        minimumBottomInset: 20,
        outerRadiusRatio: 0.062,
        bodyRadiusRatio: 0.056,
        screenRadiusRatio: 0.030,
        minimumOuterRadius: 42,
        minimumBodyRadius: 36,
        minimumScreenRadius: 18,
        shadowAlpha: 0.34
    )

    private static let classicIPhone = DeviceFrameProfile(
        hardware: .homeButton,
        railWidthRatio: 0.010,
        minimumRailWidth: 8,
        sideInsetRatio: 0.034,
        topInsetRatio: 0.115,
        bottomInsetRatio: 0.135,
        minimumSideInset: 24,
        minimumTopInset: 88,
        minimumBottomInset: 104,
        outerRadiusRatio: 0.055,
        bodyRadiusRatio: 0.050,
        screenRadiusRatio: 0.006,
        minimumOuterRadius: 38,
        minimumBodyRadius: 32,
        minimumScreenRadius: 2,
        shadowAlpha: 0.32
    )

    private static let iPad = DeviceFrameProfile(
        hardware: .iPad,
        railWidthRatio: 0.006,
        minimumRailWidth: 6,
        sideInsetRatio: 0.026,
        topInsetRatio: 0.026,
        bottomInsetRatio: 0.026,
        minimumSideInset: 22,
        minimumTopInset: 22,
        minimumBottomInset: 22,
        outerRadiusRatio: 0.033,
        bodyRadiusRatio: 0.029,
        screenRadiusRatio: 0.018,
        minimumOuterRadius: 28,
        minimumBodyRadius: 24,
        minimumScreenRadius: 10,
        shadowAlpha: 0.30
    )
}
