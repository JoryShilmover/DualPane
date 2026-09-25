// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DualPane",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "DualPaneCore", targets: ["DualPaneCore"]),
        .library(name: "DualPaneUIKit", targets: ["DualPaneUIKit"]),
        .library(name: "DualPaneSwiftUI", targets: ["DualPaneSwiftUI"]),
    ],
    targets: [
        .target(name: "DualPaneCore"),
        .target(name: "DualPaneUIKit", dependencies: ["DualPaneCore"]),
        .target(name: "DualPaneSwiftUI", dependencies: ["DualPaneCore"]),
        .testTarget(name: "DualPaneCoreTests", dependencies: ["DualPaneCore"]),
    ]
)
