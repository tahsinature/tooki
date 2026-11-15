// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Tooki",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.7"),
    ],
    targets: [
        .target(name: "TookiKit"),
        .target(name: "TookiDesignSystem", dependencies: ["TookiKit"]),
        .target(name: "ClipboardFeature", dependencies: [
            "TookiKit",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .target(name: "SnippetFeature", dependencies: [
            "TookiKit",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .target(name: "SearchFeature", dependencies: [
            "TookiKit",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .target(name: "EmojiFeature", dependencies: ["TookiKit", .product(name: "ComposableArchitecture", package: "swift-composable-architecture")]),
        .target(name: "ShelfFeature", dependencies: ["TookiKit", .product(name: "ComposableArchitecture", package: "swift-composable-architecture")]),
        .target(name: "KeepAwakeFeature", dependencies: ["TookiKit", .product(name: "ComposableArchitecture", package: "swift-composable-architecture")]),
        .executableTarget(name: "Tooki", dependencies: [
            .product(name: "Sparkle", package: "Sparkle"),
            "TookiKit", "TookiDesignSystem", "ClipboardFeature", "SnippetFeature", "SearchFeature", "EmojiFeature", "ShelfFeature", "KeepAwakeFeature",
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        ]),
        .executableTarget(name: "ComponentGallery", dependencies: ["TookiDesignSystem"]),
        .testTarget(name: "TookiKitTests", dependencies: ["TookiKit"]),
        .testTarget(name: "ClipboardFeatureTests", dependencies: ["ClipboardFeature"]),
        .testTarget(name: "SnippetFeatureTests", dependencies: ["SnippetFeature"]),
        .testTarget(name: "SearchFeatureTests", dependencies: ["SearchFeature"]),
        .testTarget(name: "EmojiFeatureTests", dependencies: ["EmojiFeature"]),
        .testTarget(name: "ShelfFeatureTests", dependencies: ["ShelfFeature"]),
        .testTarget(name: "KeepAwakeFeatureTests", dependencies: ["KeepAwakeFeature"]),
        .testTarget(name: "TookiTests", dependencies: ["Tooki", "TookiDesignSystem"]),
        .testTarget(name: "FeatureVisualTests", dependencies: [
            "Tooki", "TookiDesignSystem",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ], exclude: ["__Snapshots__"]),
        .testTarget(name: "DesignSystemTests", dependencies: [
            "TookiDesignSystem",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ], exclude: ["__Snapshots__"]),
    ]
)
