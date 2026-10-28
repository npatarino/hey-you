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
    ],
    targets: [
        .target(
            name: "HeyYouKit",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HeyYouKitTests",
            dependencies: ["HeyYouKit"]
        ),
    ]
)
