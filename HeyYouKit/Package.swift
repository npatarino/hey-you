// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeyYouKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HeyYouKit", targets: ["HeyYouKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "HeyYouKit",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HeyYouKitTests",
            dependencies: ["HeyYouKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
