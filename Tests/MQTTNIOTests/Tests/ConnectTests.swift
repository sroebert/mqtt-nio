import MQTTNIO
import XCTest

final class ConnectTests: MQTTNIOTestCase {
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
