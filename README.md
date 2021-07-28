# MQTTNIO

Non-blocking, event-driven Swift client for MQTT ([5.0](https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html) and [3.1.1](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)) build on [SwiftNIO](https://github.com/apple/swift-nio).

This library has support for WebSocket connections and TLS. It runs on all platforms Swift NIO runs on (e.g. macOS, iOS, Linux, etc.).

[![Tests](https://img.shields.io/github/workflow/status/sroebert/mqtt-nio/test/main.svg?label=Tests&style=for-the-badge)](https://github.com/sroebert/mqtt-nio/actions)
[![Swift 5.4](http://img.shields.io/badge/swift-5.4-brightgreen.svg?style=for-the-badge)](https://swift.org)
[![Release](https://img.shields.io/github/release/sroebert/mqtt-nio.svg?style=for-the-badge)](https://github.com/sroebert/mqtt-nio/releases)

## Installation

Use the SPM string to easily include the dependendency in your Package.swift file.

```swift
.package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.0.0")
```

## Supported Platforms

MQTTNIO supports the following platforms:

- Ubuntu 18.04+
- macOS 10.9+, iOS 7+, tvOS 12+ or watchOS 6+

## Dependencies

This package has four dependencies:

- [`apple/swift-nio`](https://github.com/apple/swift-nio) for IO.
- [`apple/swift-nio-ssl`](https://github.com/apple/swift-nio-ssl) for TLS.
- [`apple/swift-nio-transport-services`](https://github.com/apple/swift-nio-transport-services) to support Apple platforms as first-class citizens.
- [`apple/swift-log`](https://github.com/apple/swift-log) for logging.

This package has no additional system dependencies.

## Usage

### Create Client and Connect
```swift
let client = MQTTClient(
    configuration: .init(
        target: .host("127.0.0.1", port: 1883)
    ),
    eventLoopGroupProvider: .createNew
)
client.connect()
```

The client automatically reconnects when failing to connect or when disconnected from the broker.

### Connect to an MQTT 3.1.1 broker

```swift
let client = MQTTClient(
    configuration: .init(
        target: .host("127.0.0.1", port: 1883),
        protocolVersion: .version3_1_1
    ),
    eventLoopGroupProvider: .createNew
)
client.connect()
```

### Connect using a URL

```swift
let client = MQTTClient(configuration: .init(url: URL(string: "mqtts://test.mosquitto.org")!))
client.connect()
```

```swift
let client = MQTTClient(configuration: .init(url: URL(string: "wss://test.mosquitto.org:8081")!))
client.connect()
```

### Subscribe
```swift
client.subscribe(to: "some/topic")
```

### Unsubscribe
```swift
client.unsubscribe(from: "some/topic")
```

### Publish

```swift
client.publish("Hello World!", to: "some/topic", qos: .exactlyOnce)
```
```swift
client.publish("Hello World!", "some/topic")
```
```swift
client.publish("Hello World!", to: "some/topic", retain: true)
```

### Receive callbacks to know when the client connects/disconnects and receives messages.
```swift
client.whenConnected { response in
    print("Connected, is session present: \(response.isSessionPresent)")
}
```
```
client.whenDisconnected { reason in
    print("Disconnected: \(reason)")
}
```
```swift
client.whenMessage { message in
    print("Received: \(message)")
}
```

For platforms where the `Combine` framework is available, it is also possible to subscribe to publishers.
```swift
let cancellable = client.connectPublisher
    .sink { response in
        print("Connected, is session present: \(response.isSessionPresent)")
    }
```
```swift
let cancellable = client.disconnectPublisher
    .sink { reason in
        print("Disconnected: \(reason)")
    }
```
```swift
let cancellable1 = client.messagePublisher
    .sink { message in
        print("Received: \(message)")
    }
let cancellable2 = client.messagePublisher(forTopic: "some/topic")
    .sink { message in
        print("Received: \(message)")
    }
```

## Unit Tests

To easily run the tests locally, first generate self signed certificates followed by running docker-compose to setup the needed MQTT broker containers.
```
./mosquitto/certs/generate.sh
docker compose up
```
