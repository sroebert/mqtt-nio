import NIO
@testable import MQTTNIO
import XCTest

final class ConnectTests: MQTTNIOTestCase {
    
    private var nonExistingClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1783),
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    func testConnectAndDisconnect() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testFailureToConnect() throws {
        let client = nonExistingClient
        client.configuration.connectionTimeoutInterval = .seconds(2)
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            let error = waitForFailure(for: client.connect(), timeout: 4)
            XCTAssertFalse(client.isConnected)
            
            XCTAssertTrue(error is NIOConnectionError || error is ChannelError)
            
            wait(for: client.disconnect())
        }
    }
    
    func testReconnect() throws {
        let client1 = defaultClient
        client1.configuration.protocolVersion = .version5
        
        let topic = "mqtt-nio/tests/reconnect"
        let payload = "Hello world!"
        client1.configuration.willMessage = MQTTWillMessage(
            topic: topic,
            payload: payload
        )
        
        let client2 = defaultClient
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client2.whenMessage { message in
            XCTAssertEqual(message.topic, topic)
            XCTAssertEqual(message.payload.string, payload)
            
            expectation.fulfill()
        }
        
        wait(for: client2.connect())
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.connect())
        XCTAssertTrue(client1.isConnected)
        
        client1.configuration.willMessage = nil
        wait(for: client1.reconnect(sendWillMessage: true))
        XCTAssertTrue(client1.isConnected)
        
        wait(for: client1.disconnect(sendWillMessage: true))
        XCTAssertFalse(client1.isConnected)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testConnectionCallbacks() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            var counter = 0
            
            let connectExpectation = XCTestExpectation(description: "Received connect event")
            connectExpectation.expectedFulfillmentCount = 2
            connectExpectation.assertForOverFulfill = true
            
            var cancellable1: MQTTCancellable?
            cancellable1 = client.whenConnected { _ in
                connectExpectation.fulfill()
                
                counter += 1
                if counter == 2 {
                    cancellable1?.cancel()
                }
            }
            
            let disconnectExpectation = XCTestExpectation(description: "Received disconnect event")
            disconnectExpectation.expectedFulfillmentCount = 3
            disconnectExpectation.assertForOverFulfill = true
            
            let cancellable2 = client.whenDisconnected { reason in
                disconnectExpectation.fulfill()
                
                guard case .userInitiated = reason else {
                    XCTFail("Reason should be user initiated")
                    return
                }
            }
            
            wait(for: client.connect())
            wait(for: client.disconnect())
            
            wait(for: client.connect())
            wait(for: client.disconnect())
            
            wait(for: client.connect())
            wait(for: client.disconnect())
            
            wait(for: [connectExpectation, disconnectExpectation], timeout: 60)
            
            cancellable1?.cancel()
            cancellable2.cancel()
        }
    }
    
    func testWebsockets() throws {
        let client = wsClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
        
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testTLSWithoutVerification() throws {
        let client = tlsNoVerifyClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testWebsocketsTLSWithoutVerification() throws {
        let client = wsTLSNoVerifyClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    #if canImport(NIOSSL)
    func testNIOSSLTLS() throws {
        let client = try nioSSLTLSClient

        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    #endif
    
    #if canImport(Network)
    func testTransportServicesTLS() throws {
        guard #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) else {
            return
        }
        
        let client = try transportServicesTLSClient

        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    #endif
}
