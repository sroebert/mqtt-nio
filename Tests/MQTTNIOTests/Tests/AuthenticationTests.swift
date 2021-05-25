@testable import MQTTNIO
import XCTest

final class AuthenticationTests: MQTTNIOTestCase {
    func testSuccessLogin() throws {
        let client = authenticationClient
        client.configuration.reconnectMode = .none
        
        client.configuration.credentials = .init(username: "test", password: "p@ssw0rd")
        
        wait(for: client.connect())
        XCTAssertTrue(client.isConnected)
        
        wait(for: client.disconnect())
    }
    
    func testNotAuthorized() throws {
        let client = authenticationClient
        client.configuration.reconnectMode = .none
        
        client.configuration.credentials = .init(username: "test", password: "invalid")
        
        let expectation = XCTestExpectation(description: "Connect completed")
        client.connect().whenComplete { result in
            switch result {
            case .success:
                XCTFail()
                
            case .failure(let error):
                XCTAssertEqual((error as? MQTTConnectionError)?.serverReasonCode, .notAuthorized)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2)
    }
}
