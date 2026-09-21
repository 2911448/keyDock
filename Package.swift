// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyDock",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KeyDockCore", targets: ["KeyDockCore"]), .executable(name: "KeyDock", targets: ["KeyDock"])],
    targets: [
        .target(name: "KeyDockCore"),
        .executableTarget(name: "KeyDock", dependencies: ["KeyDockCore"]),
        .testTarget(name: "KeyDockCoreTests", dependencies: ["KeyDockCore"]),
        .testTarget(name: "KeyDockTests", dependencies: ["KeyDock", "KeyDockCore"])
    ]
)
