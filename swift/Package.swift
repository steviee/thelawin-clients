// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Envoice",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Envoice",
            targets: ["Envoice"]
        ),
    ],
    targets: [
        .target(
            name: "Envoice",
            path: "Sources/Envoice"
        ),
        .testTarget(
            name: "EnvoiceTests",
            dependencies: ["Envoice"],
            path: "Tests/EnvoiceTests"
        ),
    ]
)
