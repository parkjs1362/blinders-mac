// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Blinders",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Blinders")
    ]
)
