import Logging
import MQTTNIO
import XCTest
import NIO
import NIOTestUtils

final class MQTTNIOTests: XCTestCase {
    private var group: EventLoopGroup!
    private var eventLoop: EventLoop {
        return self.group.next()
    }
    
    override func setUp() {
        XCTAssertTrue(isLoggingConfigured)
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        self.group = nil
    }
    
    // MARK: Tests

    func testConnectAndClose() throws {
        let client = MQTTClient(eventLoopGroup: group)
        
        _ = try client.connect(configuration: .init(
            target: .host("localhost", port: 1883),
            eventLoopGroup: group,
            keepAliveInterval: .seconds(5)
        )).wait()
        
        client.addMessageListener { _, message in
            print("Received message at \(message.topic): \(message.stringValue ?? "data")")
        }
        
        client.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/message", payload: "Hello World"))
        
        _ = try client.subscribe(to: "nl.roebert.MQTT/tests/subscribe", qos: .exactlyOnce).wait()
        
        let promise = eventLoop.makePromise(of: Void.self)
        eventLoop.scheduleTask(in: .seconds(15)) {
            promise.succeed(())
        }
        try promise.futureResult.wait()
        
        _ = try client.unsubscribe(from: "nl.roebert.MQTT/tests/subscribe").wait()
        
        let promise2 = eventLoop.makePromise(of: Void.self)
        eventLoop.scheduleTask(in: .seconds(15)) {
            promise2.succeed(())
        }
        try promise2.futureResult.wait()
        
        try client.disconnect().wait()
    }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = .debug
        return handler
    }
    return true
}()
