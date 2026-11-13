// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tooki",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TookiKit"),
        .executableTarget(name: "Tooki", dependencies: ["TookiKit"]),
        .testTarget(name: "TookiKitTests", dependencies: ["TookiKit"]),
        .testTarget(name: "TookiTests", dependencies: ["Tooki"]),
    ]
)
