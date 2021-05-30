@testable import MQTTNIO
import XCTest

final class MQTT5Tests: MQTTNIOTestCase {
    
    private var limitedClient: MQTTClient {
        return MQTTClient(configuration: .init(
            target: .host("localhost", port: 1886),
            protocolVersion: .version5,
            reconnectMode: .none
        ), eventLoopGroupProvider: .shared(group))
    }
    
    func testMaxKeepAlive() throws {
        let client = limitedClient
        client.configuration.keepAliveInterval = .seconds(60)
        
        let response = wait(for: client.connect())
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.keepAliveInterval, .seconds(30))
    }
    
    func testBrokerConfiguration1() throws {
        let client = defaultClient
        client.configuration.protocolVersion = .version5
        
        let response = wait(for: client.connect())
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.brokerConfiguration.isRetainAvailable, true)
        XCTAssertNil(response?.brokerConfiguration.maximumPacketSize)
        XCTAssertEqual(response?.brokerConfiguration.maximumQoS, .exactlyOnce)
    }
    
    func testBrokerConfiguration2() throws {
        let client = limitedClient
        
        let response = wait(for: client.connect())
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.brokerConfiguration.isRetainAvailable, false)
        XCTAssertEqual(response?.brokerConfiguration.maximumPacketSize, 100)
        XCTAssertEqual(response?.brokerConfiguration.maximumQoS, .atLeastOnce)
    }
    
    func testMaximumPacketSize() throws {
        let client = limitedClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/maximum-packet-size"
        
        let smallPublish = Data(repeating: 1, count: 10)
        wait(for: client.publish(topic: topic, payload: .bytes(smallPublish.byteBuffer)))
        
        let largePubish = Data(repeating: 1, count: 100)
        let error = waitForFailure(for: client.publish(topic: topic, payload: .bytes(largePubish.byteBuffer)))
        XCTAssertEqual((error as? MQTTProtocolError)?.code, .packetTooLarge)
        
        // As the client prevents the message from being sent, it should still be connected
        XCTAssertTrue(client.isConnected)
    }
    
    func testMaximumQoS() throws {
        let client = limitedClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/maximum-qos"
        
        wait(for: client.publish(topic: topic, payload: "test1", qos: .atMostOnce))
        wait(for: client.publish(topic: topic, payload: "test2", qos: .atLeastOnce))
        wait(for: client.publish(topic: topic, payload: "test3", qos: .exactlyOnce))
    }
    
    func testNoLocal() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/no-local"
        let payload = "Hello World!"
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        client.addMessageListener { _, message, _ in
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(noLocalMessages: true)))
        wait(for: client.publish(topic: topic, payload: payload))
        wait(for: [expectation], timeout: 1)
    }
    
    func testRetainAsPublished1() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-as-published1"
        let payload = "Hello World!"
        
        // Clear retained message
        wait(for: client.publish(topic: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertFalse(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: false)))
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(topic: topic, retain: true))
    }
    
    func testRetainAsPublished2() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-as-published2"
        let payload = "Hello World!"
        
        // Clear retained message
        wait(for: client.publish(topic: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertTrue(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: true)))
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(topic: topic, retain: true))
    }
    
    func testSendOnSubscribe() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.expectedFulfillmentCount = 2
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribe)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribe)))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(topic: topic, retain: true))
    }
    
    func testSendOnSubscribeIfNotExists() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe-if-not-exists"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribeIfNotExists)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribeIfNotExists)))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(topic: topic, retain: true))
    }
    
    func testNoRetained() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe-if-not-exists"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(topic: topic, payload: payload, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        client.addMessageListener { _, message, _ in
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(topic: topic, retain: true))
    }
    
    func testUserProperties() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/user-properties"
        let payload = "Hello World!"
        let userProperties: [MQTTUserProperty] = [
            "property1": "value1",
            "property2": "value2",
            "property3": "value3"
        ]
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertEqual(message.properties.userProperties, userProperties)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic))
        
        wait(for: client.publish(
            topic: topic,
            payload: payload,
            properties: .init(
                userProperties: userProperties
            )
        ))
        wait(for: [expectation], timeout: 1)
    }
    
    func testSubscriptionIdentifiers() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic1 = "mqtt-nio/tests/subscription-identifiers/1"
        let topic2 = "mqtt-nio/tests/subscription-identifiers/2"
        let payload = "Hello World!"
        
        let expectation1 = XCTestExpectation(description: "Received payload 1")
        expectation1.assertForOverFulfill = true
        
        let expectation2 = XCTestExpectation(description: "Received payload 2")
        expectation2.assertForOverFulfill = true
        
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.properties.subscriptionIdentifiers.count, 1)
            
            switch message.properties.subscriptionIdentifiers.first {
            case 1:
                expectation1.fulfill()
            case 2:
                expectation2.fulfill()
            default:
                XCTFail("Invalid subscription identifier")
            }
        }
        
        wait(for: client.subscribe(to: topic1, identifier: 1))
        wait(for: client.subscribe(to: topic2, identifier: 2))
        
        wait(for: client.publish(topic: topic1, payload: payload))
        wait(for: client.publish(topic: topic2, payload: payload))
        wait(for: [expectation1, expectation2], timeout: 1)
    }
}
