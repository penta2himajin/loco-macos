// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocoMacOS",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LocoMacOSCore", targets: ["LocoMacOSCore"]),
        .executable(name: "LocoMacOS", targets: ["LocoMacOS"]),
    ],
    targets: [
        .target(
            name: "LocoMacOSCore",
            path: "Sources/LocoMacOSCore"
        ),
        .executableTarget(
            name: "LocoMacOS",
            dependencies: ["LocoMacOSCore"],
            path: "Sources/LocoMacOS",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "LocoMacOSCoreTests",
            dependencies: ["LocoMacOSCore"],
            path: "Tests/LocoMacOSCoreTests"
        ),
    ]
)
