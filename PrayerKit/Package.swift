// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PrayerKit",
    platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "PrayerKit", targets: ["PrayerKit"]),
    ],
    targets: [
        .target(name: "PrayerKit"),
        .testTarget(name: "PrayerKitTests", dependencies: ["PrayerKit"]),
    ]
)
