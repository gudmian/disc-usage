// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiscUsage",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "ScanKit"),
        .target(name: "CleanupKit", dependencies: ["ScanKit"]),
        .target(name: "DiscUsageUI", dependencies: ["ScanKit", "CleanupKit"]),
        .executableTarget(name: "DiscUsage", dependencies: ["DiscUsageUI"]),
        .testTarget(name: "ScanKitTests", dependencies: ["ScanKit"]),
        .testTarget(name: "CleanupKitTests", dependencies: ["CleanupKit"]),
        .testTarget(name: "DiscUsageUITests", dependencies: ["DiscUsageUI"]),
    ]
)
