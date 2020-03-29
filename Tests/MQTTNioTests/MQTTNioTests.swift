import Logging
import MQTTNio
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
        let conn = try MQTTConnection.connect(
            to: .init(ipAddress: "127.0.0.1", port: 1883),
            config: .init(keepAliveInterval: 5),
            on: eventLoop
        ).wait()
        
        try conn.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/test1", payload: "done")).wait()
        
        let promise = conn.eventLoop.makePromise(of: Void.self)
        conn.eventLoop.scheduleTask(in: .seconds(6)) {
            promise.succeed(())
        }
        try promise.futureResult.wait()
        
        try conn.publish(MQTTMessage(topic: "nl.roebert.MQTT/tests/test2", payload: "done")).wait()
        
        try conn.close().wait()
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
