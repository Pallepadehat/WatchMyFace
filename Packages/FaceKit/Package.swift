// swift-tools-version: 6.0
import PackageDescription

/// The parts of WatchMyFace that are pure logic: comparing faces, deciding when an unlock is allowed, and tracking how
/// much of the circle an enrollment has covered. No camera, no windows, no Keychain, so it all runs under `swift test`.
let package = Package(
    name: "FaceKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FaceKit", targets: ["FaceKit"])
    ],
    targets: [
        .target(name: "FaceKit"),
        .testTarget(name: "FaceKitTests", dependencies: ["FaceKit"]),
    ]
)
