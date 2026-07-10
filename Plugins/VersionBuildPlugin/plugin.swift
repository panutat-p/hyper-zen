import Foundation
import PackagePlugin

@main
struct VersionBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let generator = try context.tool(named: "VersionGenerator")
        let version = ProcessInfo.processInfo.environment["HYPER_ZEN_VERSION"] ?? "dev"
        let outputFile = context.pluginWorkDirectoryURL.appendingPathComponent("HyperZenBuildInfo.swift")

        return [
            .buildCommand(
                displayName: "Generate HyperZen build version",
                executable: generator.url,
                arguments: [context.pluginWorkDirectoryURL.path, version],
                inputFiles: [],
                outputFiles: [outputFile]
            )
        ]
    }
}
