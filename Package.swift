// swift-tools-version: 6.1.0

import PackageDescription

let package = Package(
    name: "YYJsonEncoder",
    products: [
        .library(name: "YYJsonEncoder", targets: ["YYJsonEncoder"]),
    ],
    targets: [
        .target(name: "YYJsonEncoder", dependencies: ["CYYJsonEncoder"], path: "Sources/YYJsonEncoder"),
        .target(name: "CYYJsonEncoder", dependencies: [], path: "Sources/CYYJsonEncoder"),
        .testTarget(name: "YYJsonEncoderTests", dependencies: ["YYJsonEncoder"]),
    ]
)
