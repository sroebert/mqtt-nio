// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "mqtt-nio",
    products: [
        .library(name: "MQTTNIO", targets: ["MQTTNIO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "MQTTNIO", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOWebSocket", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        .testTarget(name: "MQTTNIOTests", dependencies: [
            .target(name: "MQTTNIO"),
            .product(name: "NIOTestUtils", package: "swift-nio"),
        ]),
    ]
)
