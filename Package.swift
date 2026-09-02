// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StatusBarSecondRow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StatusBarSecondRow", targets: ["StatusBarSecondRow"])
    ],
    targets: [
        .executableTarget(name: "StatusBarSecondRow")
    ]
)
