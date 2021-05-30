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
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            let error = waitForFailure(for: client.connect())
            XCTAssertFalse(client.isConnected)
            
            XCTAssertTrue(error is NIOConnectionError)
            
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
        client2.addMessageListener { _, message, _ in
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
    
    func testConnectionListeners() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            var counter = 0
            
            let connectExpectation = XCTestExpectation(description: "Received connect event")
            connectExpectation.expectedFulfillmentCount = 2
            connectExpectation.assertForOverFulfill = true
            let listenerContext1 = client.addConnectListener { _, _, context in
                connectExpectation.fulfill()
                
                counter += 1
                if counter == 2 {
                    context.stopListening()
                }
            }
            
            let disconnectExpectation = XCTestExpectation(description: "Received disconnect event")
            disconnectExpectation.expectedFulfillmentCount = 3
            disconnectExpectation.assertForOverFulfill = true
            let listenerContext2 = client.addDisconnectListener { _, reason, _ in
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
            
            listenerContext1.stopListening()
            listenerContext2.stopListening()
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
    
    func testSSLWithoutVerification() throws {
        let client = sslNoVerifyClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testWebsocketsSSLWithoutVerification() throws {
        let client = wsSslNoVerifyClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testSSL() throws {
        let client = sslClient

        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
}
