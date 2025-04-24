// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Atomic",
    platforms: [
        .macOS(.v13) // Use latest compatible with DeviceActivity
    ],
    dependencies: [
        // Add external packages here if needed
    ],
    targets: [
        .executableTarget(
            name: "Atomic",
            dependencies: []
        )
    ]
)
