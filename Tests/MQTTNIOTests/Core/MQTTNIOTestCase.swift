import Logging
import MQTTNIO
import XCTest
import NIO
import NIOSSL

class MQTTNIOTestCase: XCTestCase {
    
    // MARK: - Vars
    
    private(set) var group: EventLoopGroup!
    
    var eventLoop: EventLoop {
        return group.next()
    }
    
    // MARK: - Set Up / Tear Down
    
    override func setUp() {
        XCTAssertTrue(isLoggingConfigured)
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try group.syncShutdownGracefully())
        group = nil
    }
    
    // MARK: - Clients
    
    var defaultClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1883),
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    var wsClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1884),
            webSockets: .enabled,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    var sslNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8883),
            tls: .forClient(certificateVerification: .none),
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    var wsSslNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8884),
            tls: .forClient(certificateVerification: .none),
            webSockets: .enabled,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
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
        ), eventLoopGroupProvider: .shared(group))
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
        handler.logLevel = .debug
        return handler
    }
    return true
}()
