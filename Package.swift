// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WoWServerControlCenter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WoWServerControlCenter", targets: ["WoWServerControlCenter"])],
    targets: [
        .executableTarget(
            name: "WoWServerControlCenter",
            path: "Sources/WoWServerControlCenter"
        )
    ]
)
