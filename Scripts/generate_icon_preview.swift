import Foundation

@main
struct GenerateIconPreview {
    static func main() {
        let outputURL = URL(fileURLWithPath: "Design/AppIcon-preview.png")
        IconRenderer.exportPreviewIcon(to: outputURL)
    }
}
