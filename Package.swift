// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "mqtt-nio",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "MQTTNio", targets: ["MQTTNio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "MQTTNio", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        .testTarget(name: "MQTTNioTests", dependencies: [
            .target(name: "MQTTNio"),
            .product(name: "NIOTestUtils", package: "swift-nio"),
        ]),
    ]
)
