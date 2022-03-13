// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugsBunny",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "BugsBunny", targets: ["BugsBunny"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "BugsBunny", dependencies: []),
        .testTarget(name: "BugsBunnyTests", dependencies: ["BugsBunny"]),
    ],
    swiftLanguageVersions: [.v5]
)
