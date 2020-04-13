# MQTTNIO

Non-blocking, event-driven Swift client for MQTT ([3.1.1](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)) build on [SwiftNIO](https://github.com/apple/swift-nio).

[![Build Status](https://travis-ci.org/sroebert/mqtt-nio.svg?branch=master)](https://travis-ci.org/sroebert/mqtt-nio)

## Installation

Use the SPM string to easily include the dependendency in your Package.swift file.

```swift
.package(url: "https://github.com/sroebert/mqtt-nio.git", from: ...)
```

## Supported Platforms

MQTTNIO supports the following platforms:

- Ubuntu 14.04+
- macOS 10.12+

## Dependencies

This package has three dependencies:

- [`apple/swift-nio`](https://github.com/apple/swift-nio) for IO
- [`apple/swift-nio-ssl`](https://github.com/apple/swift-nio-ssl) for TLS
- [`apple/swift-log`](https://github.com/apple/swift-log) for logging

This package has no additional system dependencies.

## Usage

### Create Client and Connect
```swift
let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
let client = MQTTClient(
    configuration: .init(
        target: .host("127.0.0.1", port: 1883),
    ),
    eventLoopGroup: group
)
client.connect()
```

The client automatically reconnects when failing to connect or when disconnected from the broker.

### Subscribe
```swift
client.subscribe(to: "some/topic").whenComplete { result in
    switch result {
    case .success(.success):
        print("Subscribed!")
    case .success(.failure):
        print("Server rejected")
    case .failure:
        print("Server did not respond")
    }
}
```

### Unsubscribe
```swift
client.unsubscribe(from: "some/topic").whenComplete { result in
    switch result {
    case .success:
        print("Unsubscribed!")
    case .failure:
        print("Server did not respond")
    }
}
```

### Publish

```swift
client.publish(
    topic: "some/topic",
    payload: "Hello World!",
    qos: .exactlyOnce
)
```
```swift
client.publish(topic: "some/topic", payload: "Hello World!")
```
```swift
client.publish(
    topic: "some/topic",
    payload: "Hello World!",
    retain: true
)
```

### Add listeners to know when the client connects/disconnects, receives errors and messages. 
```swift
client.addConnectListener { _, response, _ in
    print("Connected: \(response.returnCode)")
}
client.addDisconnectListener { _, reason, _ in
    print("Disconnected: \(reason)")
}
```
```swift
client.addErrorListener { _, error, _ in
    print("Error: \(error)")
}
```
```swift
client.addMessageListener { _, message, _ in
    print("Received: \(message)")
}
```
