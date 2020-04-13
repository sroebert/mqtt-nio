import MQTTNIO
import XCTest

final class ConnectTests: MQTTNIOTestCase {
    func testConnectAndDisconnect() throws {
        let client = plainClient
        
        wait(for: client.connect())
        XCTAssertTrue(client.isConnected)
        
        wait(for: client.disconnect())
        XCTAssertFalse(client.isConnected)
    }
    
    func testSSLWithoutVerification() throws {
        let client = sslNoVerifyClient
        
        wait(for: client.connect())
        XCTAssertTrue(client.isConnected)
        
        wait(for: client.disconnect())
        XCTAssertFalse(client.isConnected)
    }
    
    func testSSL() throws {
        let client = sslClient
        
        wait(for: client.connect())
        XCTAssertTrue(client.isConnected)
        
        wait(for: client.disconnect())
        XCTAssertFalse(client.isConnected)
    }
}
