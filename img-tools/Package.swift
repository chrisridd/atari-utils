// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "img-tools",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "png2img", targets: ["png2img"]),
        .executable(name: "img2png", targets: ["img2png"]),
        .library(name: "Utils", targets: ["Utils"]),
        .library(name: "Atari", targets: ["Atari"]),
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "png2img",
            dependencies: [
                "Utils",
                "Atari",
            ]
        ),
        .executableTarget(
            name: "img2png",
            dependencies: [
                "Utils",
                "Atari",
            ]
        ),
        .target(name: "Utils"),
        .target(name: "Atari"),
        .testTarget(name: "AtariTests", dependencies: ["Atari", "Utils"]),
    ]
)
