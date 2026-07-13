import AppKit

enum IconRenderer {
    private static let canvasSize: CGFloat = 1024

    private static let brownTop = NSColor(
        calibratedRed: 154.0 / 255.0,
        green: 107.0 / 255.0,
        blue: 69.0 / 255.0,
        alpha: 1
    )
    private static let brownBottom = NSColor(
        calibratedRed: 107.0 / 255.0,
        green: 68.0 / 255.0,
        blue: 35.0 / 255.0,
        alpha: 1
    )
    private static let monkeyFace = NSColor.white
    private static let monkeyDetail = NSColor(
        calibratedRed: 92.0 / 255.0,
        green: 58.0 / 255.0,
        blue: 33.0 / 255.0,
        alpha: 1
    )

    // json-swift head proportions (relative to head radius).
    private static let earRadiusRatio: CGFloat = 0.081 / 0.142
    private static let muzzleWidthRatio: CGFloat = 0.176 / 0.142
    private static let muzzleHeightRatio: CGFloat = 0.103 / 0.142
    private static let eyeRadiusRatio: CGFloat = 0.018 / 0.142
    private static let noseRadiusRatio: CGFloat = 0.015 / 0.142

    // Keep the complete monkey head, including its ears, at 70% of the canvas width.
    private static let appIconHeadWidthRatio: CGFloat = 0.70
    private static let appIconEarOffsetRatio: CGFloat = 0.92
    private static var appIconHeadRadiusRatio: CGFloat {
        appIconHeadWidthRatio / (2 * (appIconEarOffsetRatio + earRadiusRatio))
    }

    static func makeAppIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let tileInset = size * 0.06
        let tileBounds = bounds.insetBy(dx: tileInset, dy: tileInset)
        let tilePath = CGPath(
            roundedRect: tileBounds,
            cornerWidth: size * 0.22,
            cornerHeight: size * 0.22,
            transform: nil
        )

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -size * 0.012),
            blur: size * 0.035,
            color: NSColor.black.withAlphaComponent(0.18).cgColor
        )
        context.setFillColor(brownBottom.cgColor)
        context.addPath(tilePath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(tilePath)
        context.clip()
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: 1, y: -1)
        drawBackgroundGradient(in: context, bounds: bounds)
        context.restoreGState()

        drawDetailedMonkeyHead(
            center: NSPoint(x: size / 2, y: size * 0.505),
            headRadius: size * appIconHeadRadiusRatio,
            faceColor: monkeyFace,
            detailColor: monkeyDetail
        )

        image.unlockFocus()
        return image
    }

    /// json-swift-style face: ears with inner detail, muzzle, eyes, and nose.
    private static func drawDetailedMonkeyHead(
        center: NSPoint,
        headRadius: CGFloat,
        faceColor: NSColor,
        detailColor: NSColor
    ) {
        let earRadius = headRadius * earRadiusRatio
        let muzzleScale: CGFloat = 0.78
        let muzzleW = headRadius * muzzleWidthRatio * muzzleScale
        let muzzleH = headRadius * muzzleHeightRatio * muzzleScale
        let eyeRadius = headRadius * eyeRadiusRatio
        let noseRadius = headRadius * noseRadiusRatio

        faceColor.setFill()
        for earOffset in [-headRadius * appIconEarOffsetRatio, headRadius * appIconEarOffsetRatio] {
            let earX = center.x + earOffset
            NSBezierPath(ovalIn: NSRect(
                x: earX - earRadius,
                y: center.y - earRadius * 0.78,
                width: earRadius * 2,
                height: earRadius * 2 * 0.78
            )).fill()

            let innerRadius = earRadius * 0.48
            detailColor.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: earX - innerRadius,
                y: center.y - innerRadius * 0.78,
                width: innerRadius * 2,
                height: innerRadius * 2 * 0.78
            )).fill()
            faceColor.setFill()
        }

        NSBezierPath(ovalIn: NSRect(
            x: center.x - headRadius,
            y: center.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        )).fill()

        detailColor.setFill()
        // PIL/json-swift uses top-left origin; AppKit uses bottom-left — flip vertical offsets.
        let muzzleBottom = center.y - headRadius * 0.12 - muzzleH
        NSBezierPath(
            roundedRect: NSRect(
                x: center.x - muzzleW / 2,
                y: muzzleBottom,
                width: muzzleW,
                height: muzzleH
            ),
            xRadius: muzzleH * 0.45,
            yRadius: muzzleH * 0.45
        ).fill()

        let eyeY = center.y + headRadius * 0.18
        for eyeOffset in [-headRadius * 0.34, headRadius * 0.34] {
            NSBezierPath(ovalIn: NSRect(
                x: center.x + eyeOffset - eyeRadius,
                y: eyeY - eyeRadius,
                width: eyeRadius * 2,
                height: eyeRadius * 2
            )).fill()
        }

        faceColor.setFill()
        let noseY = center.y - headRadius * 0.36
        NSBezierPath(ovalIn: NSRect(
            x: center.x - noseRadius,
            y: noseY - noseRadius,
            width: noseRadius * 2,
            height: noseRadius * 2
        )).fill()
    }

    static func exportAppIcons(to directory: URL) {
        let icons: [(filename: String, size: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]

        for icon in icons {
            writePNG(makeAppIcon(size: CGFloat(icon.size)), to: directory.appendingPathComponent(icon.filename))
        }
    }

    static func exportPreviewIcon(to url: URL, size: CGFloat = 1024) {
        writePNG(makeAppIcon(size: size), to: url)
    }

    private static func writePNG(_ image: NSImage, to url: URL) {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            return
        }

        try? png.write(to: url)
    }

    private static func drawBackgroundGradient(in context: CGContext, bounds: CGRect) {
        let colors = [brownTop.cgColor, brownBottom.cgColor] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.minY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY),
                options: []
            )
        }
    }
}
