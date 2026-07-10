import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: VersionGenerator OUTPUT_DIRECTORY VERSION")
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let version = arguments[2]
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
let outputFile = outputDirectory.appendingPathComponent("HyperZenBuildInfo.swift")
let source = """
enum HyperZenBuildInfo {
    static let version = "\(version)"
}
"""

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try source.write(to: outputFile, atomically: true, encoding: .utf8)
