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
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        self.group = nil
    }
    
    // MARK: Tests

    func testConnectAndClose() throws {
        let client = MQTTClient(configuration: .init(
//            target: .host("broker.hivemq.com", port: 1883),
            target: .host("127.0.0.1", port: 1883),
            keepAliveInterval: .seconds(5)
        ), eventLoopGroup: group)
        
        client.addConnectListener { _, response, _ in
            print("Connected: \(response.returnCode)")
        }
        client.addDisconnectListener { _, reason, _ in
            print("Disconnected: \(reason)")
        }
        
        client.connect()
        
        client.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/message1", payload: "Hello World"))
        client.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/message2", payload: "Hello World"))
        
        let promise = eventLoop.makePromise(of: Void.self)
        eventLoop.scheduleTask(in: .seconds(15)) {
            promise.succeed(())
        }
        try promise.futureResult.wait()
        
        client.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/message3", payload: "Hello World"))
        
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
        handler.logLevel = .trace
        return handler
    }
    return true
}()
