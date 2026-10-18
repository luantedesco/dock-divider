// swift-tools-version:5.9
// The app is built by build.sh, which bundles this package's executable into Dock Divider.app.
// DockDividerCore holds the geometry, apart from AppKit and Accessibility, so it can be tested.
import PackageDescription

let package = Package(
    name: "DockDivider",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DockDividerCore"),
        .executableTarget(name: "DockDivider", dependencies: ["DockDividerCore"]),
        .testTarget(name: "DockDividerCoreTests", dependencies: ["DockDividerCore"]),
    ]
)
