// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftVisionML",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftVisionML",
            targets: ["SwiftVisionML"]
        )
    ],
    targets: [
        .target(
            name: "SwiftVisionML",
            path: "Sources/SwiftVisionML"
        ),
        .testTarget(
            name: "SwiftVisionMLTests",
            dependencies: ["SwiftVisionML"],
            path: "Tests/SwiftVisionMLTests"
        )
    ]
)
