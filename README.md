# MQTTNIO

MQTT 3.1.1 Client written on the SwiftNIO framework.

* Written in Swift 5.
* Uses `Logging` framework for logging debug messages.
* Based on [MQTT 3.1.1 Specification](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)

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

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "1.0.0")
]
```

## License
MIT
