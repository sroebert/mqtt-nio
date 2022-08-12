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
    
    var tlsGroup: EventLoopGroup {
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            return tsGroup
        }
        #endif
        return group
    }
    
    var eventLoop: EventLoop {
        return group.next()
    }
    
    private static func createEventLoopGroup() -> EventLoopGroup {
        return MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    #if canImport(Network)
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    var tsGroup: EventLoopGroup {
        return _tsGroup
    }
    
    private var _tsGroup: EventLoopGroup!
    
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    var tsEventLoop: EventLoop {
        return tsGroup.next()
    }
    
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    private static func createTsEventLoopGroup() -> NIOTSEventLoopGroup {
        return NIOTSEventLoopGroup()
    }
    #endif
    
    // MARK: - Set Up / Tear Down
    
    override func setUp() {
        XCTAssertTrue(isLoggingConfigured)
        group = Self.createEventLoopGroup()
        
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            _tsGroup = Self.createTsEventLoopGroup()
        }
        #endif
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try group.syncShutdownGracefully())
        group = nil
        
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            XCTAssertNoThrow(try tsGroup.syncShutdownGracefully())
            _tsGroup = nil
        }
        #endif
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
        ), eventLoopGroupProvider: .shared(tlsGroup))
    }
    
    var wsTLSNoVerifyClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 8884),
            tls: .noVerification,
            webSockets: .enabled,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(tlsGroup))
    }
    
    // This should use `canImport(NIOSSL)`, will change when it works with SwiftUI previews.
    #if os(macOS) || os(Linux)
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
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
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
            ), eventLoopGroupProvider: .shared(tsGroup))
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
