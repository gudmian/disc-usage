// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiscUsage",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "ScanKit"),
        .target(name: "CleanupKit", dependencies: ["ScanKit"]),
        .target(name: "UninstallKit", dependencies: ["CleanupKit"]),
        .target(name: "DiscUsageUI", dependencies: ["ScanKit", "CleanupKit", "UninstallKit"]),
        .executableTarget(name: "DiscUsage", dependencies: ["DiscUsageUI"]),
        .testTarget(name: "ScanKitTests", dependencies: ["ScanKit"]),
        .testTarget(name: "CleanupKitTests", dependencies: ["CleanupKit"]),
        .testTarget(name: "UninstallKitTests", dependencies: ["UninstallKit"]),
        .testTarget(name: "DiscUsageUITests", dependencies: ["DiscUsageUI"]),
    ]
)
