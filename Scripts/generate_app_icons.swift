import Foundation

@main
struct GenerateAppIcons {
    static func main() {
        let outputDirectory = URL(
            fileURLWithPath: "Hyperzen/Assets.xcassets/AppIcon.appiconset",
            isDirectory: true
        )
        IconRenderer.exportAppIcons(to: outputDirectory)
    }
}
