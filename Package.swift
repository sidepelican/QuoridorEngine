// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "QuoridorEngine",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "QuoridorEngine", targets: ["QuoridorEngine"]),
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "QuoridorEngine",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
            ]
        ),
        .testTarget(
            name: "QuoridorEngineTests",
            dependencies: ["QuoridorEngine"]
        ),
        .executableTarget(
            name: "Run",
            dependencies: ["QuoridorEngine"]
        ),
    ]
)
