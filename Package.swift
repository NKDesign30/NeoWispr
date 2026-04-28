// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NeoWispr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NeoWispr", targets: ["NeoWispr"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.3.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.13.6"),
    ],
    targets: [
        .executableTarget(
            name: "NeoWispr",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "NeoWispr",
            exclude: [
                "Resources/Info.plist",
                "Resources/NeoWispr.entitlements",
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/Fonts"),
            ]
        ),
        .testTarget(
            name: "NeoWisprTests",
            dependencies: ["NeoWispr"],
            path: "Tests/NeoWisprTests"
        )
    ]
)
