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
        client.whenMessage { message in
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
        let cancellable = client.whenMessage { message in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertFalse(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: false)))
        wait(for: client.publish(payload, to: topic, retain: true))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        
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
        let cancellable = client.whenMessage { message in
            XCTAssertEqual(message.payload.string, payload)
            XCTAssertTrue(message.retain)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainAsPublished: true)))
        wait(for: client.publish(payload, to: topic, retain: true))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        
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
        let cancellable = client.whenMessage { message in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribe)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribe)))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        
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
        let cancellable = client.whenMessage { message in
            XCTAssertEqual(message.payload.string, payload)
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribeIfNotExists)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .sendOnSubscribeIfNotExists)))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        
        // Clear again
        wait(for: client.publish(to: topic, retain: true))
    }
    
    func testNoRetained() throws {
        let client = defaultClient
        wait(for: client.connect())
        
        let topic = "mqtt-nio/tests/retain-handling/do-not-send"
        let payload = "Hello World!"
        
        // Setup retained message
        wait(for: client.publish(payload, to: topic, retain: true))
        
        let expectation = XCTestExpectation(description: "Received payload")
        expectation.isInverted = true
        let cancellable = client.whenMessage { message in
            expectation.fulfill()
        }
        
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: client.subscribe(to: topic, options: .init(retainedMessageHandling: .doNotSend)))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
        
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
        client.whenMessage { message in
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
        
        client.whenMessage { message in
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
        client2.whenMessage { message in
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
        client2.whenMessage { message in
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
        client2.whenMessage { message in
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
        client2.whenMessage { message in
            expectation.fulfill()
        }
        wait(for: client2.subscribe(to: topic))
        
        wait(for: client1.disconnect(sendWillMessage: true))
        
        wait(seconds: 2)
        wait(for: client1.connect())
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testRequestResponse() throws {
        let client1 = defaultClient
        let client2 = defaultClient
        
        let requestTopic = "mqtt-nio/tests/request-response/request"
        let responseTopic = "mqtt-nio/tests/request-response/response"
        let requestPayload = "Hello world 1"
        let responsePayload = "Hello world 2"
        let correlationData = Data((0..<16).map { _ in UInt8.random(in: 0..<255) })
        
        wait(for: client1.connect())
        wait(for: client1.subscribe(to: responseTopic))
        
        let responseExpectation = XCTestExpectation(description: "Received response")
        client1.whenMessage { message in
            XCTAssertEqual(message.payload.string, responsePayload)
            XCTAssertNotNil(message.properties.correlationData)
            
            guard let messageCorrelationData = message.properties.correlationData else {
                return
            }
            
            XCTAssertEqual(messageCorrelationData, correlationData)
            
            responseExpectation.fulfill()
        }
        
        wait(for: client2.connect())
        wait(for: client2.subscribe(to: requestTopic))
        
        let requestExpectation = XCTestExpectation(description: "Received request")
        client2.whenMessage { [weak client2] message in
            XCTAssertEqual(message.payload.string, requestPayload)
            XCTAssertNotNil(message.properties.responseTopic)
            XCTAssertNotNil(message.properties.correlationData)
            
            guard
                let messageResponseTopic = message.properties.responseTopic,
                let messageCorrelationData = message.properties.correlationData
            else {
                return
            }
            
            XCTAssertEqual(messageResponseTopic, responseTopic)
            XCTAssertEqual(messageCorrelationData, correlationData)
            
            client2?.publish(responsePayload, to: messageResponseTopic, properties: .init(
                correlationData: messageCorrelationData
            ))
            
            requestExpectation.fulfill()
        }
        
        wait(for: client1.publish(requestPayload, to: requestTopic, properties: .init(
            responseTopic: responseTopic,
            correlationData: correlationData
        )))
        
        wait(for: [requestExpectation, responseExpectation], timeout: 1)
    }
}
