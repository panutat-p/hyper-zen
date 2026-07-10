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
            ]
        ),
        .executableTarget(
            name: "hyper-zen",
            dependencies: ["HyperZen"]
        ),
        .testTarget(
            name: "HyperZenTests",
            dependencies: ["HyperZen"]
        )
    ]
)
