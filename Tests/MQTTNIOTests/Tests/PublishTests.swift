@testable import MQTTNIO
import XCTest

final class PublishTests: MQTTNIOTestCase {
    func testQoS0() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let topic = "mqtt-nio/tests/qos0"
            let payload = "Hello World!"
            let qos: MQTTQoS = .atMostOnce
            
            let expectation = XCTestExpectation(description: "Received payload")
            expectation.assertForOverFulfill = true
            let listenerContext = client.addMessageListener { _, message, _ in
                XCTAssertEqual(message.payload.string, payload)
                XCTAssertEqual(message.qos, qos)
                expectation.fulfill()
            }
            
            let response = wait(for: client.subscribe(to: topic, qos: qos))
            XCTAssertEqual(response?.result, .success(qos))
            
            wait(for: client.publish(topic: topic, payload: payload, qos: qos))
            
            wait(for: [expectation], timeout: 2)
            
            wait(for: client.disconnect())
            
            listenerContext.stopListening()
        }
    }
    
    func testQoS1() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let topic = "mqtt-nio/tests/qos1"
            let payload = "Hello World!"
            let qos: MQTTQoS = .atLeastOnce
            
            let expectation = XCTestExpectation(description: "Received payload")
            expectation.assertForOverFulfill = true
            let listenerContext = client.addMessageListener { _, message, _ in
                XCTAssertEqual(message.payload.string, payload)
                XCTAssertEqual(message.qos, qos)
                expectation.fulfill()
            }
            
            let response = wait(for: client.subscribe(to: topic, qos: qos))
            XCTAssertEqual(response?.result, .success(qos))
            
            wait(for: client.publish(topic: topic, payload: payload, qos: qos))
            
            wait(for: [expectation], timeout: 2)
            
            wait(for: client.disconnect())
            
            listenerContext.stopListening()
        }
    }
    
    func testQoS2() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let topic = "mqtt-nio/tests/qos2"
            let payload = "Hello World!"
            let qos: MQTTQoS = .exactlyOnce
            
            let expectation = XCTestExpectation(description: "Received payload")
            expectation.assertForOverFulfill = true
            let listenerContext = client.addMessageListener { _, message, _ in
                XCTAssertEqual(message.payload.string, payload)
                XCTAssertEqual(message.qos, qos)
                expectation.fulfill()
            }
            
            let response = wait(for: client.subscribe(to: topic, qos: qos))
            XCTAssertEqual(response?.result, .success(qos))
            
            wait(for: client.publish(topic: topic, payload: payload, qos: qos))
            
            wait(for: [expectation], timeout: 2)
            
            wait(for: client.disconnect())
            
            listenerContext.stopListening()
        }
    }
    
    func testRetain() throws {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let topic = "mqtt-nio/tests/retain"
            let payload = "Hello World!"
            
            // Clear
            wait(for: client.publish(topic: topic, retain: true))
            
            let expectation1 = XCTestExpectation(description: "Received payload")
            expectation1.assertForOverFulfill = true
            let listenerContext1 = client.addMessageListener { _, message, context in
                XCTAssertEqual(message.payload.string, payload)
                XCTAssertFalse(message.retain)
                expectation1.fulfill()
                
                context.stopListening()
            }
            
            wait(for: client.subscribe(to: topic))
            wait(for: client.publish(topic: topic, payload: payload, retain: true))
            wait(for: [expectation1], timeout: 2)
            
            let expectation2 = XCTestExpectation(description: "Received payload")
            expectation2.assertForOverFulfill = true
            let listenerContext2 = client.addMessageListener { _, message, context in
                XCTAssertEqual(message.payload.string, payload)
                XCTAssertTrue(message.retain)
                expectation2.fulfill()
            }
            
            wait(for: client.disconnect())
            wait(for: client.connect())
            wait(for: client.subscribe(to: topic))

            wait(for: [expectation2], timeout: 2)
            
            // Clear again
            wait(for: client.publish(topic: topic, retain: true))
            
            wait(for: client.disconnect())
            
            listenerContext1.stopListening()
            listenerContext2.stopListening()
        }
    }
    
    func testKeepSession() {
        let client = defaultClient
        client.configuration.clean = false
        client.configuration.connectProperties.sessionExpiry = .afterInterval(.seconds(60))
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            let topic = "mqtt-nio/tests/keep-session"
            let payload = "Hello World!"
            
            wait(for: client.connect())
            wait(for: client.subscribe(to: topic))
            
            let expectation = XCTestExpectation(description: "Received payload")
            expectation.assertForOverFulfill = true
            let listenerContext = client.addMessageListener { _, message, context in
                XCTAssertEqual(message.payload.string, payload)
                expectation.fulfill()
            }
            
            wait(for: client.disconnect())
            wait(for: client.connect())
            wait(for: client.publish(topic: topic, payload: payload))
            
            wait(for: [expectation], timeout: 2)
            
            wait(for: client.disconnect())
            
            listenerContext.stopListening()
        }
    }
    
    func testMultiSubscribe() {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let response = wait(for: client.subscribe(to: [
                MQTTSubscription(topicFilter: "mqtt-nio/tests/multi-subscribe/1", qos: .atMostOnce),
                MQTTSubscription(topicFilter: "mqtt-nio/tests/multi-subscribe/2", qos: .atLeastOnce),
                MQTTSubscription(topicFilter: "mqtt-nio/tests/multi-subscribe/3", qos: .exactlyOnce)
            ]))
            
            XCTAssertNotNil(response)
            XCTAssertEqual(response!.results.count, 3)
            XCTAssertEqual(response!.results[0], .success(.atMostOnce))
            XCTAssertEqual(response!.results[1], .success(.atLeastOnce))
            XCTAssertEqual(response!.results[2], .success(.exactlyOnce))
            
            wait(for: client.disconnect())
        }
    }
    
    func testUnsubscribe() {
        let client = defaultClient
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            let topic = "mqtt-nio/tests/unsubscribe"
            let payload = "Hello World!"
            
            let expectation = XCTestExpectation(description: "Received payload")
            expectation.assertForOverFulfill = true
            let listenerContext = client.addMessageListener { _, message, _ in
                XCTAssertEqual(message.payload.string, payload)
                expectation.fulfill()
            }
            
            wait(for: client.subscribe(to: topic))
            wait(for: client.publish(topic: topic, payload: payload))
            
            wait(for: client.unsubscribe(from: topic))
            wait(for: client.publish(topic: topic, payload: payload))
            
            wait(for: [expectation], timeout: 2)
            
            wait(for: client.disconnect())
            
            listenerContext.stopListening()
        }
    }
    
    func testKeepAlive() {
        let client = defaultClient
        client.configuration.keepAliveInterval = .seconds(1)
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
            
            wait(for: client.connect())
            
            wait(seconds: 3)
            
            let topic = "mqtt-nio/tests/keep-alive"
            let payload = "Hello World!"
            
            XCTAssertTrue(client.isConnected)
            wait(for: client.publish(topic: topic, payload: payload))
            
            wait(for: client.disconnect())
        }
    }
    
    func testInvalidClient() {
        let client = defaultClient
        client.configuration.clean = false
        client.configuration.connectProperties.sessionExpiry = .afterInterval(.seconds(60))
        client.configuration.clientId = ""
        
        for version in MQTTProtocolVersion.allCases {
            client.configuration.protocolVersion = version
        
            let expectation = XCTestExpectation(description: "Connect completed")
            client.connect().whenComplete { result in
                switch result {
                case .success:
                    XCTFail("Should not be able to succesfully connect with an empty client id")
                    
                case .failure(let error):
                    let reasonCode = (error as? MQTTConnectionError)?.serverReasonCode
                    XCTAssertTrue(reasonCode == .clientIdentifierNotValid || reasonCode == .unspecifiedError)
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 2)
        }
    }
}
