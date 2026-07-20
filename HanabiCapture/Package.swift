// swift-tools-version:5.9
import PackageDescription

// HanabiCapture holds the platform-independent capture DOMAIN: the synchronized
// timeline, timestamp normalization, time-ordered ring buffer, attitude interpolation,
// capture-service protocols, session/permission state, mocks, and the replay engine.
// It depends only on Foundation and HanabiCore, so its pure logic is verified by
// `swift test`. Concrete AVFoundation/CoreMotion/CoreLocation services live in the app
// target and conform to these protocols.
let package = Package(
    name: "HanabiCapture",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HanabiCapture", targets: ["HanabiCapture"])
    ],
    dependencies: [
        .package(path: "../HanabiCore")
    ],
    targets: [
        .target(
            name: "HanabiCapture",
            dependencies: [
                .product(name: "HanabiCore", package: "HanabiCore")
            ],
            path: "Sources/HanabiCapture"
        ),
        .testTarget(
            name: "HanabiCaptureTests",
            dependencies: ["HanabiCapture"],
            path: "Tests/HanabiCaptureTests"
        )
    ]
)
