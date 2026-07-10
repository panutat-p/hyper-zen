// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "robot-swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RobotSwift", targets: ["RobotSwift"]),
        .executable(name: "robot-swift", targets: ["robot-swift"])
    ],
    targets: [
        .target(
            name: "RobotSwift",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "robot-swift",
            dependencies: ["RobotSwift"]
        ),
        .testTarget(
            name: "RobotSwiftTests",
            dependencies: ["RobotSwift"]
        )
    ]
)
