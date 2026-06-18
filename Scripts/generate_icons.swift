import Foundation

@main
struct GenerateIcons {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            fputs(
                "Usage: generate_icons preview <output.png>\n" +
                    "       generate_icons iconset <output-directory>\n",
                stderr
            )
            exit(1)
        }

        guard let outputPath = args.dropFirst().first else {
            fputs("Missing output path\n", stderr)
            exit(1)
        }

        switch command {
        case "preview":
            IconRenderer.exportPreviewIcon(to: URL(fileURLWithPath: outputPath))
        case "iconset":
            IconRenderer.exportAppIcons(
                to: URL(fileURLWithPath: outputPath, isDirectory: true)
            )
        default:
            fputs("Unknown command: \(command)\n", stderr)
            exit(1)
        }
    }
}
