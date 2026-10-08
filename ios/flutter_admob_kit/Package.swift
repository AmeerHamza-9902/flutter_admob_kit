// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_admob_kit",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "flutter-admob-kit", targets: ["flutter_admob_kit"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "13.7.0")
    ],
    targets: [
        .target(
            name: "flutter_admob_kit",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_admob_kit")
            ]
        )
    ]
)
