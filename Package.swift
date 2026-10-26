// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatHub",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChatHubCore", targets: ["ChatHubCore"]),
        .executable(name: "ChatHub", targets: ["ChatHub"]),
    ],
    targets: [
        .target(name: "ChatHubCore"),
        .executableTarget(
            name: "ChatHub",
            dependencies: ["ChatHubCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ChatHubCoreTests", dependencies: ["ChatHubCore"]),
        .testTarget(name: "ChatHubPresentationTests", dependencies: ["ChatHub"]),
    ]
)
