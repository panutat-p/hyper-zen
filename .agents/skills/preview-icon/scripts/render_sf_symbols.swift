import AppKit
import Foundation

private struct PreviewSpec: Decodable {
    let sets: [IconSet]
}

private struct IconSet: Decodable {
    let icons: [Icon]
}

private struct Icon: Decodable {
    let symbol: String
    let colors: [String]?
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("preview-icon: \(message)\n".utf8))
    exit(1)
}

private func color(named name: String) -> NSColor {
    switch name {
    case "white": .white
    case "black": .black
    case "systemBlue": .systemBlue
    case "systemBrown": .systemBrown
    case "systemGray": .systemGray
    case "systemGreen": .systemGreen
    case "systemIndigo": .systemIndigo
    case "systemOrange": .systemOrange
    case "systemPink": .systemPink
    case "systemPurple": .systemPurple
    case "systemRed": .systemRed
    case "systemTeal": .systemTeal
    case "systemYellow": .systemYellow
    case "label": .labelColor
    case "secondaryLabel": .secondaryLabelColor
    default: fail("unsupported color '\(name)'")
    }
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: swift render_sf_symbols.swift <spec.json> <output-directory>")
}

let specURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
private let spec: PreviewSpec

do {
    spec = try JSONDecoder().decode(PreviewSpec.self, from: Data(contentsOf: specURL))
    try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
    )
} catch {
    fail("could not read the preview specification: \(error)")
}

let pixelSize = 192
let pointSize: CGFloat = 70

for (setIndex, iconSet) in spec.sets.enumerated() {
    for (stateIndex, icon) in iconSet.icons.enumerated() {
        guard let symbol = NSImage(
            systemSymbolName: icon.symbol,
            accessibilityDescription: icon.symbol
        ) else {
            fail("SF Symbol '\(icon.symbol)' is unavailable on this Mac")
        }

        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        if let colorNames = icon.colors, !colorNames.isEmpty {
            configuration = configuration.applying(
                NSImage.SymbolConfiguration(paletteColors: colorNames.map(color(named:)))
            )
        }

        guard let configured = symbol.withSymbolConfiguration(configuration) else {
            fail("could not configure SF Symbol '\(icon.symbol)'")
        }
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fail("could not allocate a bitmap for '\(icon.symbol)'")
        }

        bitmap.size = NSSize(width: pixelSize, height: pixelSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

        let imageSize = configured.size
        let scale = min(
            CGFloat(pixelSize) * 0.72 / imageSize.width,
            CGFloat(pixelSize) * 0.72 / imageSize.height
        )
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        configured.draw(in: NSRect(
            x: (CGFloat(pixelSize) - drawSize.width) / 2,
            y: (CGFloat(pixelSize) - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        ))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fail("could not encode '\(icon.symbol)' as PNG")
        }

        let filename = "set-\(setIndex)-state-\(stateIndex).png"
        do {
            try png.write(to: outputDirectory.appendingPathComponent(filename))
        } catch {
            fail("could not write '\(filename)': \(error)")
        }
    }
}
