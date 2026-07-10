import AppKit
import Foundation

public enum HyperZenProcesses {
    public static func all() -> [HyperZenProcess] {
        NSWorkspace.shared.runningApplications
            .map { app in
                HyperZenProcess(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? app.bundleIdentifier ?? "pid-\(app.processIdentifier)",
                    path: app.bundleURL?.path
                )
            }
            .sorted { $0.pid < $1.pid }
    }

    public static func exists(pid: Int32) -> Bool {
        NSRunningApplication(processIdentifier: pid) != nil
    }

    public static func findName(pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    public static func findPath(pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleURL?.path
    }

    public static func findIDs(named name: String) -> [Int32] {
        let needle = name.lowercased()
        return all()
            .filter { process in
                process.name.lowercased().contains(needle) ||
                (process.path?.lowercased().contains(needle) ?? false)
            }
            .map(\.pid)
    }

    @discardableResult
    public static func run(_ launchPath: String, arguments: [String] = []) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    public static func kill(pid: Int32) throws {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            throw HyperZenError.notFound("Process \(pid) was not found")
        }

        if !app.terminate() {
            app.forceTerminate()
        }
    }
}
