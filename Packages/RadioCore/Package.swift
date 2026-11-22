// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadioCore",
    platforms: [.iOS("27.1"), .macOS(.v14)],
    products: [
        .library(name: "RadioCore", targets: ["RadioCore"])
    ],
    targets: [
        .target(name: "RadioCore"),
        .testTarget(name: "RadioCoreTests", dependencies: ["RadioCore"])
    ]
)
