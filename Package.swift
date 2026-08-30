// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cursie",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Cursie", targets: ["Cursie"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "Cursie",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CursieTests",
            dependencies: ["Cursie"],
            path: "Tests"
        )
    ]
)
