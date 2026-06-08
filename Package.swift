// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CapeForge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CapeForge", targets: ["CapeForge"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "CapeForge",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CapeForgeTests",
            dependencies: ["CapeForge"],
            path: "Tests"
        )
    ]
)
