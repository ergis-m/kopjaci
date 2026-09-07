// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kopjaci",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "Kopjaci", path: "Sources/Kopjaci")
    ]
)
