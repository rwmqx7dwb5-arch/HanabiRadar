// swift-tools-version:5.9
import PackageDescription

// HanabiCore is the platform-independent estimation engine (no Apple frameworks).
// It builds and its tests run on any Swift toolchain (`swift test`), which keeps
// the science verifiable independently of Xcode, the camera, or a device.
let package = Package(
    name: "HanabiCore",
    // The core uses no iOS-18-specific APIs, so it declares a conservative platform
    // floor for broad toolchain compatibility during validation. The app itself still
    // targets iOS 18 via its own project settings.
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HanabiCore", targets: ["HanabiCore"])
    ],
    targets: [
        .target(
            name: "HanabiCore",
            path: "Sources/HanabiCore"
        ),
        .testTarget(
            name: "HanabiCoreTests",
            dependencies: ["HanabiCore"],
            path: "Tests/HanabiCoreTests"
        )
    ]
)
