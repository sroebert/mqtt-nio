@testable import MQTTNIO
import XCTest

final class ConfigurationTests: XCTestCase {
    
    private func configuration(forURL urlString: String) -> MQTTConfiguration {
        guard let url = URL(string: urlString) else {
            XCTFail("Invalid url passed")
            fatalError("Invalid url passed")
        }
        return MQTTConfiguration(url: url)
    }
    
    func testIpURL() throws {
        let configuration = configuration(forURL: "192.168.1.123")
        XCTAssertEqual(configuration.target, .host("192.168.1.123", port: 1883))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testIpPortURL() throws {
        let configuration = configuration(forURL: "192.168.1.123:1234")
        XCTAssertEqual(configuration.target, .host("192.168.1.123", port: 1234))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testHostURL() throws {
        let configuration = configuration(forURL: "test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 1883))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testSchemeURL() throws {
        let configuration = configuration(forURL: "mqtt://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 1883))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testSSLURL() throws {
        let configuration = configuration(forURL: "mqtts://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 8883))
        XCTAssertNotNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testWebSocketURL() throws {
        let configuration = configuration(forURL: "ws://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 80))
        XCTAssertNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .enabled)
    }
    
    func testWebSocketURLWithPath() throws {
        let configuration = configuration(forURL: "ws://test.mosquitto.org/some-path")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 80))
        XCTAssertNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .init(path: "/some-path"))
    }
    
    func testWebSocketHTTPURL() throws {
        let configuration = configuration(forURL: "http://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 80))
        XCTAssertNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .enabled)
    }
    
    func testWebSocketSSLURL() throws {
        let configuration = configuration(forURL: "wss://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 443))
        XCTAssertNotNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .enabled)
    }
    
    func testWebSocketHTTPSSLURL() throws {
        let configuration = configuration(forURL: "https://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 443))
        XCTAssertNotNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .enabled)
    }
    
    func testPortURL() throws {
        let configuration = configuration(forURL: "mqtt://test.mosquitto.org:8883")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 8883))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
    
    func testWsPortURL() throws {
        let configuration = configuration(forURL: "wss://test.mosquitto.org:8091")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 8091))
        XCTAssertNotNil(configuration.tls)
        XCTAssertEqual(configuration.webSockets, .enabled)
    }
    
    func testInvalidScheme() throws {
        let configuration = configuration(forURL: "ssh://test.mosquitto.org")
        XCTAssertEqual(configuration.target, .host("test.mosquitto.org", port: 1883))
        XCTAssertNil(configuration.tls)
        XCTAssertNil(configuration.webSockets)
    }
}
