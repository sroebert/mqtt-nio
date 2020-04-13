import Logging
import MQTTNIO
import XCTest
import NIO
import NIOSSL

class MQTTNIOTestCase: XCTestCase {
    private(set) var group: EventLoopGroup!
    var eventLoop: EventLoop {
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
    
    // MARK: - Clients
    
    var plainClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1883)
        ), eventLoopGroup: group)
    }
    
    var sslNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8883),
            tls: .forClient(certificateVerification: .none)
        ), eventLoopGroup: group)
    }
    
    var sslClient: MQTTClient {
        let rootDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let caCertifcateURL = rootDir.appendingPathComponent("Docker/certs/ca.crt")
        let caCertificate = try! NIOSSLCertificate.fromPEMFile(caCertifcateURL.path)[0]
        
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8883),
            tls: .forClient(
                certificateVerification: .noHostnameVerification,
                trustRoots: .certificates([caCertificate])
            )
        ), eventLoopGroup: group)
    }
    
    var authenticationClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1884)
        ), eventLoopGroup: group)
    }
    
    // MARK: - Utils
    
    func wait(seconds: TimeInterval) {
        let expectation = XCTestExpectation(description: "Waiting")
        eventLoop.scheduleTask(in: .seconds(Int64(seconds))) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 1)
    }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = .error
        return handler
    }
    return true
}()
