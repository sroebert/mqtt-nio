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

    func testConnectAndDisconnect() throws {
        let client = MQTTClient(configuration: .init(
            target: .host("127.0.0.1", port: 1883)
        ), eventLoopGroup: group)
        
        try client.connect().wait()
        try client.disconnect().wait()
    }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = .notice
        return handler
    }
    return true
}()
