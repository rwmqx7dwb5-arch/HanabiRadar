// swift-tools-version:5.9
import PackageDescription

// HanabiCore is the platform-independent estimation engine (no Apple frameworks).
// It builds and its tests run on any Swift toolchain (`swift test`), which keeps
// the science verifiable independently of Xcode, the camera, or a device.
let package = Package(
    name: "HanabiCore",
    platforms: [
        .iOS(.v18),
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
