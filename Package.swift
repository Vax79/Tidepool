// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tidepool",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Tidepool", path: "Sources/Tidepool")
    ]
)
