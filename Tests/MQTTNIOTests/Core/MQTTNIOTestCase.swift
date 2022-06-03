import Logging
@testable import MQTTNIO
import XCTest
import NIO
#if canImport(NIOSSL)
import NIOSSL
#endif
#if canImport(Network)
import Network
#endif
import NIOTransportServices

class MQTTNIOTestCase: XCTestCase {
    
    // MARK: - Types
    
    enum ClientSetupError: Error {
        case invalidCertificateData
    }
    
    // MARK: - Vars
    
    private(set) var group: EventLoopGroup!
    
    var eventLoop: EventLoop {
        return group.next()
    }
    
    private static func createEventLoopGroup() -> EventLoopGroup {
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            return NIOTSEventLoopGroup()
        }
        #endif
        return MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    // MARK: - Set Up / Tear Down
    
    override func setUp() {
        XCTAssertTrue(isLoggingConfigured)
        group = Self.createEventLoopGroup()
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
    
    var tlsNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8883),
            tls: .noVerification,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    var wsTLSNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8884),
            tls: .noVerification,
            webSockets: .enabled,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    #if canImport(NIOSSL)
    var nioSSLTLSClient: MQTTClient {
        get throws {
            let rootDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let caCertifcateURL = rootDir.appendingPathComponent("mosquitto/certs/ca.crt")
            let caCertificate = try NIOSSLCertificate.fromPEMFile(caCertifcateURL.path)[0]
            
            var tlsConfig = TLSConfiguration.makeClientConfiguration()
            tlsConfig.certificateVerification = .noHostnameVerification
            tlsConfig.trustRoots = .certificates([caCertificate])
            
            return MQTTClient(configuration: .init(
                target: .host("localhost", port: 8883),
                tls: .nioSSL(tlsConfig)
            ), eventLoopGroupProvider: .shared(group))
        }
    }
    #endif
    
    #if canImport(Network)
    var transportServicesTLSClient: MQTTClient {
        get throws {
            let rootDir = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let caCertifcateURL = rootDir.appendingPathComponent("mosquitto/certs/ca.der")
            
            let caCertificateData = try Data(contentsOf: caCertifcateURL)
            guard let caCertificate = SecCertificateCreateWithData(nil, caCertificateData as CFData) else {
                throw ClientSetupError.invalidCertificateData
            }
            
            let tlsConfig = TSTLSConfiguration(
                certificateVerification: .noHostnameVerification,
                trustRoots: .certificates([caCertificate])
            )
            
            return MQTTClient(configuration: .init(
                target: .host("localhost", port: 8883),
                tls: .transportServices(tlsConfig)
            ), eventLoopGroupProvider: .shared(group))
        }
    }
    #endif
    
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
