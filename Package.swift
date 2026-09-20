// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "zenv",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "zenv", targets: ["zenv"]),
        .library(name: "ZenvCore", targets: ["ZenvCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "ZenvCore",
            linkerSettings: [
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "zenv",
            dependencies: [
                "ZenvCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ZenvCoreTests",
            dependencies: ["ZenvCore", "zenv"]
        ),
    ]
)
