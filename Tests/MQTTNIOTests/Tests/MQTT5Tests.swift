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
    
    func testDefaultBrokerConfiguration() throws {
        let client = defaultClient
        client.configuration.protocolVersion = .version5
        
        let response = wait(for: client.connect())
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.brokerConfiguration.isRetainAvailable, true)
        XCTAssertNil(response?.brokerConfiguration.maximumPacketSize)
        XCTAssertEqual(response?.brokerConfiguration.maximumQoS, .exactlyOnce)
    }
    
    func testLimitedBrokerConfiguration() throws {
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
        wait(for: client.publish(.bytes(smallPublish.byteBuffer), to: topic))
        
        let largePubish = Data(repeating: 1, count: 100)
        let error = waitForFailure(for: client.publish(.bytes(largePubish.byteBuffer), to: topic))
        XCTAssertEqual((error as? MQTTProtocolError)?.code, .packetTooLarge)
        
        // As the client prevents the message from being sent, it should still be connected
        XCTAssertTrue(client.isConnected)
    }
    
    func testMaximumQoS() throws {
        let client = limitedClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/maximum-qos"
        
        wait(for: client.publish("test1", to: topic, qos: .atMostOnce))
        wait(for: client.publish("test2", to: topic, qos: .atLeastOnce))
        wait(for: client.publish("test3", to: topic, qos: .exactlyOnce))
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
        wait(for: client.publish(payload, to: topic))
        wait(for: [expectation], timeout: 1)
    }
    
    func testRetainAsPublishedFalse() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-as-published-false"
        let payload = "Hello World!"
        
        // Clear retained message
        wait(for: client.publish(to: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertFalse(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: false)))
        wait(for: client.publish(payload, to: topic, retain: true))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(to: topic, retain: true))
    }
    
    func testRetainAsPublishedTrue() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-as-published-true"
        let payload = "Hello World!"
        
        // Clear retained message
        wait(for: client.publish(to: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client.addMessageListener { _, message, _ in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertTrue(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: true)))
        wait(for: client.publish(payload, to: topic, retain: true))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(to: topic, retain: true))
    }
    
    func testSendOnSubscribe() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(payload, to: topic, retain: true))
        
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
        wait(for: client.publish(to: topic, retain: true))
    }
    
    func testSendOnSubscribeIfNotExists() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe-if-not-exists"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(payload, to: topic, retain: true))
        
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
        wait(for: client.publish(to: topic, retain: true))
    }
    
    func testNoRetained() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/send-on-subscribe-if-not-exists"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(payload, to: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        client.addMessageListener { _, message, _ in
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: [expectation], timeout: 1)
        
        // Clear again
        wait(for: client.publish(to: topic, retain: true))
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
            payload,
            to: topic,
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
        
        wait(for: client.publish(payload, to: topic1))
        wait(for: client.publish(payload, to: topic2))
        wait(for: [expectation1, expectation2], timeout: 1)
    }
    
    func testWillMessage() throws {
        let topic = "mqtt-nio/tests/will-message"
        let payload = "This is a will message"
        
        let client1 = defaultClient
        client1.configuration.willMessage = MQTTWillMessage(
            topic: topic,
            payload: payload
        )
        wait(for: client1.connect())
        
        let client2 = defaultClient
        wait(for: client2.connect())
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client2.addMessageListener { _, message, _ in
            XCTAssertEqual(message.topic, topic)
            XCTAssertEqual(message.payload.string, payload)
            
            expectation.fulfill()
        }
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.disconnect(sendWillMessage: true))
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testNoWillMessage() throws {
        let topic = "mqtt-nio/tests/no-will-message"
        let payload = "This is a will message"
        
        let client1 = defaultClient
        client1.configuration.willMessage = MQTTWillMessage(
            topic: topic,
            payload: payload
        )
        wait(for: client1.connect())
        
        let client2 = defaultClient
        wait(for: client2.connect())
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        client2.addMessageListener { _, message, _ in
            expectation.fulfill()
        }
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.disconnect(sendWillMessage: false))
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testWillMessageProperties() throws {
        let topic = "mqtt-nio/tests/will-message-properties"
        let payload = "This is a will message"
        let userProperties: [MQTTUserProperty] = [
            "key1": "some-value-1",
            "key2": "some-value-2"
        ]
        
        let client1 = defaultClient
        client1.configuration.willMessage = MQTTWillMessage(
            topic: topic,
            payload: payload,
            properties: .init(userProperties: userProperties)
        )
        wait(for: client1.connect())
        
        let client2 = defaultClient
        wait(for: client2.connect())
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.assertForOverFulfill = true
        client2.addMessageListener { _, message, _ in
            XCTAssertEqual(message.topic, topic)
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertEqual(message.properties.userProperties, userProperties)
            
            expectation.fulfill()
        }
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.disconnect(sendWillMessage: true))
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testWillMessageDelay() throws {
        let topic = "mqtt-nio/tests/will-message-delay"
        let payload = "This is a will message"
        
        let client1 = defaultClient
        client1.configuration.willMessage = MQTTWillMessage(
            topic: topic,
            payload: payload,
            properties: .init(delayInterval: .seconds(5))
        )
        wait(for: client1.connect())
        
        let client2 = defaultClient
        wait(for: client2.connect())
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        client2.addMessageListener { _, message, _ in
            expectation.fulfill()
        }
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.disconnect(sendWillMessage: true))
        
        wait(seconds: 2)
        wait(for: client1.connect())
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testSessionExpiryAtClose() throws {
        // TODO: Implement
    }
    
    func testSessionExpiryAfterInterval() throws {
        // TODO: Implement
    }
    
    func testRequestResponse() throws {
        // TODO: Implement
    }
}
