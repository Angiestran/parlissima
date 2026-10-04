// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tala",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.4"),
    ],
    targets: [
        .executableTarget(
            name: "Tala",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "Sources/Tala",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
