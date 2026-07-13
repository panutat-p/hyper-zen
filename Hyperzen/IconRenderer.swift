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

    static let statusFrameCount = 8

    private struct RunPose {
        let bob: CGFloat
        let lean: CGFloat
        let leftFoot: NSPoint
        let rightFoot: NSPoint
        let leftHand: NSPoint
        let rightHand: NSPoint
    }

    // Exaggerated keyframe poses (offsets in scale units from body center).
    private static let runPoses: [RunPose] = [
        RunPose(bob: 0.8,  lean: 0.6,  leftFoot: NSPoint(x: -2.2, y: -4.8), rightFoot: NSPoint(x:  2.4, y: -1.2), leftHand: NSPoint(x: -3.4, y:  0.2), rightHand: NSPoint(x:  3.0, y:  2.4)),
        RunPose(bob: 1.8,  lean: 0.9,  leftFoot: NSPoint(x: -0.4, y: -3.6), rightFoot: NSPoint(x: -1.8, y: -4.9), leftHand: NSPoint(x: -2.6, y:  1.8), rightHand: NSPoint(x:  2.0, y: -0.4)),
        RunPose(bob: 0.8,  lean: 0.6,  leftFoot: NSPoint(x:  2.4, y: -1.2), rightFoot: NSPoint(x: -2.2, y: -4.8), leftHand: NSPoint(x:  3.0, y:  2.4), rightHand: NSPoint(x: -3.4, y:  0.2)),
        RunPose(bob: 1.8,  lean: 0.9,  leftFoot: NSPoint(x: -1.8, y: -4.9), rightFoot: NSPoint(x: -0.4, y: -3.6), leftHand: NSPoint(x:  2.0, y: -0.4), rightHand: NSPoint(x: -2.6, y:  1.8)),
        RunPose(bob: 0.8,  lean: -0.6, leftFoot: NSPoint(x:  2.2, y: -4.8), rightFoot: NSPoint(x: -2.4, y: -1.2), leftHand: NSPoint(x:  3.4, y:  0.2), rightHand: NSPoint(x: -3.0, y:  2.4)),
        RunPose(bob: 1.8,  lean: -0.9, leftFoot: NSPoint(x:  0.4, y: -3.6), rightFoot: NSPoint(x:  1.8, y: -4.9), leftHand: NSPoint(x:  2.6, y:  1.8), rightHand: NSPoint(x: -2.0, y: -0.4)),
        RunPose(bob: 0.8,  lean: -0.6, leftFoot: NSPoint(x: -2.4, y: -1.2), rightFoot: NSPoint(x:  2.2, y: -4.8), leftHand: NSPoint(x: -3.0, y:  2.4), rightHand: NSPoint(x:  3.4, y:  0.2)),
        RunPose(bob: 1.8,  lean: -0.9, leftFoot: NSPoint(x:  1.8, y: -4.9), rightFoot: NSPoint(x:  0.4, y: -3.6), leftHand: NSPoint(x: -2.0, y: -0.4), rightHand: NSPoint(x:  2.6, y:  1.8)),
    ]

    /// Static resting monkey shown when keep-awake is disabled.
    static func makeStatusIdleIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let unitScale = size / 18.0
        drawIdleMonkey(canvasSize: size, unitScale: unitScale, fillColor: .black, strokeColor: .black)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Renders one frame of a RunCat-style running monkey for the menu bar.
    static func makeStatusFrame(frame: Int, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let unitScale = size / 18.0
        drawRunningMonkey(
            pose: runPoses[frame % runPoses.count],
            canvasSize: size,
            unitScale: unitScale,
            fillColor: .black,
            strokeColor: .black
        )

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawIdleMonkey(
        canvasSize: CGFloat,
        unitScale: CGFloat,
        fillColor: NSColor,
        strokeColor: NSColor
    ) {
        fillColor.setFill()
        strokeColor.setStroke()

        let cx = canvasSize / 2
        let bodyCenter = NSPoint(x: cx, y: canvasSize * 0.42)

        let limbWidth = 1.5 * unitScale
        drawLimb(
            from: NSPoint(x: cx - 0.8 * unitScale, y: bodyCenter.y - 1.7 * unitScale),
            to: NSPoint(x: cx - 2.0 * unitScale, y: bodyCenter.y - 3.2 * unitScale),
            width: limbWidth
        )
        drawLimb(
            from: NSPoint(x: cx + 0.8 * unitScale, y: bodyCenter.y - 1.7 * unitScale),
            to: NSPoint(x: cx + 2.0 * unitScale, y: bodyCenter.y - 3.2 * unitScale),
            width: limbWidth
        )
        drawLimb(
            from: NSPoint(x: cx - 1.5 * unitScale, y: bodyCenter.y + 1.5 * unitScale),
            to: NSPoint(x: cx - 2.2 * unitScale, y: bodyCenter.y - 0.5 * unitScale),
            width: limbWidth
        )
        drawLimb(
            from: NSPoint(x: cx + 1.5 * unitScale, y: bodyCenter.y + 1.5 * unitScale),
            to: NSPoint(x: cx + 2.2 * unitScale, y: bodyCenter.y - 0.5 * unitScale),
            width: limbWidth
        )

        NSBezierPath(ovalIn: NSRect(
            x: bodyCenter.x - 2.4 * unitScale,
            y: bodyCenter.y - 2.6 * unitScale,
            width: 4.8 * unitScale,
            height: 5.4 * unitScale
        )).fill()

        let headCenter = NSPoint(x: cx, y: bodyCenter.y + 4.0 * unitScale)
        let headRadius = 2.9 * unitScale
        drawHeadWithEars(center: headCenter, headRadius: headRadius, earRadius: 1.3 * unitScale, earOffsetFactor: 0.9)
    }

    private static func drawRunningMonkey(
        pose: RunPose,
        canvasSize: CGFloat,
        unitScale: CGFloat,
        fillColor: NSColor,
        strokeColor: NSColor
    ) {
        fillColor.setFill()
        strokeColor.setStroke()

        let cx = canvasSize / 2 + pose.lean * unitScale
        let bodyCenter = NSPoint(x: cx, y: canvasSize * 0.40 + pose.bob * unitScale)
        let limbWidth = 1.8 * unitScale

        let leftHip = NSPoint(x: bodyCenter.x - 0.9 * unitScale, y: bodyCenter.y - 1.6 * unitScale)
        let rightHip = NSPoint(x: bodyCenter.x + 0.9 * unitScale, y: bodyCenter.y - 1.6 * unitScale)
        let leftShoulder = NSPoint(x: bodyCenter.x - 1.6 * unitScale, y: bodyCenter.y + 1.4 * unitScale)
        let rightShoulder = NSPoint(x: bodyCenter.x + 1.6 * unitScale, y: bodyCenter.y + 1.4 * unitScale)

        let leftFoot = offset(pose.leftFoot, from: bodyCenter, scale: unitScale)
        let rightFoot = offset(pose.rightFoot, from: bodyCenter, scale: unitScale)
        let leftHand = offset(pose.leftHand, from: bodyCenter, scale: unitScale)
        let rightHand = offset(pose.rightHand, from: bodyCenter, scale: unitScale)

        drawBentLimb(from: leftHip, to: leftFoot, bend: 0.55 * unitScale, width: limbWidth)
        drawBentLimb(from: rightHip, to: rightFoot, bend: -0.55 * unitScale, width: limbWidth)
        drawBentLimb(from: leftShoulder, to: leftHand, bend: 0.45 * unitScale, width: limbWidth)
        drawBentLimb(from: rightShoulder, to: rightHand, bend: -0.45 * unitScale, width: limbWidth)

        NSBezierPath(ovalIn: NSRect(
            x: bodyCenter.x - 2.5 * unitScale,
            y: bodyCenter.y - 2.4 * unitScale,
            width: 5.0 * unitScale,
            height: 5.2 * unitScale
        )).fill()

        let headCenter = NSPoint(x: bodyCenter.x, y: bodyCenter.y + 3.8 * unitScale)
        let headRadius = 3.0 * unitScale
        drawHeadWithEars(center: headCenter, headRadius: headRadius, earRadius: 1.4 * unitScale, earOffsetFactor: 0.85)
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

    private static func drawHeadWithEars(
        center headCenter: NSPoint,
        headRadius: CGFloat,
        earRadius: CGFloat,
        earOffsetFactor: CGFloat
    ) {
        for earOffset in [-headRadius * earOffsetFactor, headRadius * earOffsetFactor] {
            NSBezierPath(ovalIn: NSRect(
                x: headCenter.x + earOffset - earRadius,
                y: headCenter.y - earRadius,
                width: earRadius * 2,
                height: earRadius * 2
            )).fill()
        }
        NSBezierPath(ovalIn: NSRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        )).fill()
    }

    private static func offset(_ point: NSPoint, from center: NSPoint, scale: CGFloat) -> NSPoint {
        NSPoint(x: center.x + point.x * scale, y: center.y + point.y * scale)
    }

    private static func drawBentLimb(
        from start: NSPoint,
        to end: NSPoint,
        bend: CGFloat,
        width: CGFloat
    ) {
        let mid = NSPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.001)
        let knee = NSPoint(
            x: mid.x + (-dy / length) * bend,
            y: mid.y + (dx / length) * bend
        )
        drawLimb(from: start, to: knee, width: width)
        drawLimb(from: knee, to: end, width: width)
    }

    private static func drawLimb(from start: NSPoint, to end: NSPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
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
