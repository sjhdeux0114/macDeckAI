// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDeckLab",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "macdeck-probe", targets: ["MacDeckProbe"]),
               .executable(name: "MacDeck", targets: ["MacDeck"])],
    targets: [.executableTarget(name: "MacDeckProbe", linkerSettings: [
        .linkedFramework("Virtualization"), .linkedFramework("Metal")
    ]), .executableTarget(name: "MacDeck", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SwiftUI"), .linkedFramework("GameController"), .linkedFramework("Metal")])]
)
