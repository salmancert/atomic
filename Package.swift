// swift-tools-version: 6.1
import PackageDescription

// The iOS app itself is built from Atomic.xcodeproj (see Scripts/build-ipa.sh).
// This package exposes the platform independent habit engine so it can be built,
// tested and run anywhere — including CI without an iOS SDK.
let package = Package(
    name: "Atomic",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "AtomicCore", targets: ["AtomicCore"]),
        .executable(name: "AtomicDemo", targets: ["AtomicDemo"])
    ],
    targets: [
        .target(
            name: "AtomicCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "AtomicDemo",
            dependencies: ["AtomicCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AtomicCoreTests",
            dependencies: ["AtomicCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
