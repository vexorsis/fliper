// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fliper",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Fliper", targets: ["Fliper"]),
    ],
    targets: [
        .target(name: "Fliper", path: "Sources/Fliper"),
    ]
)
