// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Hyperzen",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "HyperzenCore",
            path: "Hyperzen",
            exclude: [
                "main.swift",
                "Info.plist",
                "Assets.xcassets",
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .testTarget(
            name: "HyperzenTests",
            dependencies: ["HyperzenCore"],
            path: "Tests/HyperzenTests"
        ),
    ]
)
