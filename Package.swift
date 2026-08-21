// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacCleaner",
            path: "Sources/MacCleaner",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MacCleanerTests",
            dependencies: ["MacCleaner"],
            path: "Tests/MacCleanerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
