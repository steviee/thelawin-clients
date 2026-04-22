// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Thelawin",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Thelawin",
            targets: ["Thelawin"]
        ),
    ],
    targets: [
        .target(
            name: "Thelawin",
            path: "Sources/Thelawin"
        ),
        .testTarget(
            name: "ThelawinTests",
            dependencies: ["Thelawin"],
            path: "Tests/ThelawinTests"
        ),
    ]
)
