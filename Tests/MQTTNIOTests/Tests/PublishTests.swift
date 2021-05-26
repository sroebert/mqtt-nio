@testable import MQTTNIO
import XCTest

final class PublishTests: MQTTNIOTestCase {
    func testQoS0() throws {
        let client = plainClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/qos0"
        let payload = "Hello World!"
        let qos: MQTTQoS = .atMostOnce
        
        let expectation = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertEqual(message.qos, qos)
            expectation.fulfill()
        }
        
        let response = wait(for: client.subscribe(to: topic, qos: qos))
        XCTAssertEqual(response?.result, .success(qos))
        
        wait(for: client.publish(topic: topic, payload: payload, qos: qos))
        
        wait(for: [expectation], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testQoS1() throws {
        let client = plainClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/qos1"
        let payload = "Hello World!"
        let qos: MQTTQoS = .atMostOnce
        
        let expectation = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertEqual(message.qos, qos)
            expectation.fulfill()
        }
        
        let response = wait(for: client.subscribe(to: topic, qos: qos))
        XCTAssertEqual(response?.result, .success(qos))
        
        wait(for: client.publish(topic: topic, payload: payload, qos: qos))
        
        wait(for: [expectation], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testQoS2() throws {
        let client = plainClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/qos2"
        let payload = "Hello World!"
        let qos: MQTTQoS = .exactlyOnce
        
        let expectation = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertEqual(message.qos, qos)
            expectation.fulfill()
        }
        
        let response = wait(for: client.subscribe(to: topic, qos: qos))
        XCTAssertEqual(response?.result, .success(qos))
        
        wait(for: client.publish(topic: topic, payload: payload, qos: qos))
        
        wait(for: [expectation], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testRetain() throws {
        let client = plainClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain"
        let payload = "Hello World!"
        
        wait(for: client.publish(topic: topic, retain: true))
        
        let expectation1 = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, context in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertFalse(message.retain)
            expectation1.fulfill()
            
            context.stopListening()
        }
        
        wait(for: client.subscribe(to: topic))
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        wait(for: [expectation1], timeout: 2)
        
        let expectation2 = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, context in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertTrue(message.retain)
            expectation2.fulfill()
        }
        
        wait(for: client.disconnect())
        wait(for: client.connect())
        wait(for: client.subscribe(to: topic))

        wait(for: [expectation2], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testKeepSession() {
        let client = plainClient
        client.configuration.clean = false
        
        let topic = "mqtt-nio/tests/keep-session"
        let payload = "Hello World!"
        
        wait(for: client.connect())
        wait(for: client.subscribe(to: topic))
        
        let expectation = XCTestExpectation(description: "Received payload")
        client.addMessageListener { _, message, context in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.disconnect())
        wait(for: client.connect())
        wait(for: client.publish(topic: topic, payload: payload))
        
        wait(for: [expectation], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testMultiSubscribe() {
        let client = plainClient
        wait(for: client.connect())
        
        let response = wait(for: client.subscribe(to: [
            MQTTSubscription(topic: "mqtt-nio/tests/multi-subscribe/1", qos: .atMostOnce),
            MQTTSubscription(topic: "mqtt-nio/tests/multi-subscribe/2", qos: .atLeastOnce),
            MQTTSubscription(topic: "mqtt-nio/tests/multi-subscribe/3", qos: .exactlyOnce)
        ]))
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response!.results.count, 3)
        XCTAssertEqual(response!.results[0], .success(.atMostOnce))
        XCTAssertEqual(response!.results[1], .success(.atLeastOnce))
        XCTAssertEqual(response!.results[2], .success(.exactlyOnce))
        
        wait(for: client.disconnect())
    }
    
    func testUnsubscribe() {
        let client = plainClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/unsubscribe"
        let payload = "Hello World!"
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic))
        wait(for: client.publish(topic: topic, payload: payload))
        
        wait(for: client.unsubscribe(from: topic))
        wait(for: client.publish(topic: topic, payload: payload))
        
        wait(seconds: 1)
        
        wait(for: [expectation], timeout: 2)
        
        wait(for: client.disconnect())
    }
    
    func testKeepAlive() {
        let client = plainClient
        client.configuration.keepAliveInterval = .seconds(1)
        wait(for: client.connect())
        
        wait(seconds: 3)
        
        let topic = "mqtt-nio/tests/keep-alive"
        let payload = "Hello World!"
        
        XCTAssertTrue(client.isConnected)
        wait(for: client.publish(topic: topic, payload: payload))
        
        wait(for: client.disconnect())
    }
    
    func testInvalidClient() {
        let client = plainClient
        client.configuration.clean = false
        client.configuration.clientId = ""
        client.configuration.reconnectMode = .none
        
        let expectation = XCTestExpectation(description: "Connect completed")
        client.connect().whenComplete { result in
            switch result {
            case .success:
                XCTFail()
                
            case .failure(let error):
                XCTAssertEqual((error as? MQTTConnectionError)?.serverReasonCode, .clientIdentifierNotValid)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2)
    }
}
