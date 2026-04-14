// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "yt-tools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "yt-tools",
            targets: ["YTToolsApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "YTToolsApp",
            path: "Sources/YTToolsApp",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
