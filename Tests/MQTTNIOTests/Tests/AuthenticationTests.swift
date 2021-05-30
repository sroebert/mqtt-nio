@testable import MQTTNIO
import XCTest

final class AuthenticationTests: MQTTNIOTestCase {
    
    private var authenticationClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1885),
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    func testSuccessLogin() throws {
        let client = authenticationClient
        client.configuration.credentials = .init(username: "test", password: "p@ssw0rd")
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            XCTAssertTrue(client.isConnected)
            
            wait(for: client.disconnect())
            XCTAssertFalse(client.isConnected)
        }
    }
    
    func testNotAuthorized() throws {
        let client = authenticationClient
        client.configuration.credentials = .init(username: "test", password: "invalid")
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
        
            let expectation = XCTestExpectation(description: "Connect completed")
            client.connect().whenComplete { result in
                switch result {
                case .success:
                    XCTFail("Password is invalid, so connect cannot succeed")
                    
                case .failure(let error):
                    XCTAssertEqual((error as? MQTTConnectionError)?.serverReasonCode, .notAuthorized)
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 2)
            
            XCTAssertFalse(client.isConnected)
        }
    }
}
