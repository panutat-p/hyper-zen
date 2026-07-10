// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "hyper-zen",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HyperZen", targets: ["HyperZen"]),
        .executable(name: "hyper-zen", targets: ["hyper-zen"])
    ],
    targets: [
        .target(
            name: "HyperZen",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics")
            ],
            plugins: ["VersionBuildPlugin"]
        ),
        .executableTarget(
            name: "hyper-zen",
            dependencies: ["HyperZen"]
        ),
        .executableTarget(
            name: "VersionGenerator",
            path: "Plugins/VersionGenerator"
        ),
        .plugin(
            name: "VersionBuildPlugin",
            capability: .buildTool(),
            dependencies: ["VersionGenerator"]
        ),
        .testTarget(
            name: "HyperZenTests",
            dependencies: ["HyperZen"]
        )
    ]
)
