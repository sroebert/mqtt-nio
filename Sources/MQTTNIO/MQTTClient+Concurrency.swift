import Foundation
import NIO

#if compiler(>=5.5) && canImport(_Concurrency)

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension MQTTClient {
    
    // MARK: - Connection
    
    /// Starts connecting to the broker indicating by the `configuration`.
    /// - Returns: The `MQTTConnectResponse` returned from the broker.
    @discardableResult
    public func connect() async throws -> MQTTConnectResponse {
        return try await connect().get()
    }
    
    /// Disconnects from the broker.
    /// - Parameters:
    ///   - sendWillMessage: If `true` a 5.0 MQTT broker will send the Will message after disconnection. The default value is `false`.
    ///   - sessionExpiry: Optionally a different session expiry can be passed when disconnecting. The default value is `nil`.
    ///   - userProperties: The user properties to send with the disconnect message to a 5.0 MQTT broker.
    public func disconnect(
        sendWillMessage: Bool = false,
        sessionExpiry: MQTTConfiguration.SessionExpiry? = nil,
        userProperties: [MQTTUserProperty] = []
    ) async throws {
        try await disconnect(
            sendWillMessage: sendWillMessage,
            sessionExpiry: sessionExpiry,
            userProperties: userProperties
        ).get()
    }
    
    /// Disconnects and reconnects to the broker, making sure the updating `configuration` values
    /// are in use.
    /// - Parameters:
    ///   - sendWillMessage: If `true` a 5.0 MQTT broker will send the Will message after disconnection. The default value is `false`.
    ///   - sessionExpiry: Optionally a different session expiry can be passed when disconnecting. The default value is `nil`.
    ///   - userProperties: The user properties to send with the disconnect message to a 5.0 MQTT broker.
    public func reconnect(
        sendWillMessage: Bool = false,
        sessionExpiry: MQTTConfiguration.SessionExpiry? = nil,
        userProperties: [MQTTUserProperty] = []
    ) async throws {
        try await reconnect(
            sendWillMessage: sendWillMessage,
            sessionExpiry: sessionExpiry,
            userProperties: userProperties
        ).get()
    }
    
    // MARK: - Publish
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameter message: The message to publish.
    public func publish(_ message: MQTTMessage) async throws {
        try await publish(message).get()
    }
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameters:
    ///   - payload: The optional payload of the message. The default is `nil`.
    ///   - topic: The topic for the message.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    public func publish(
        _ payload: MQTTPayload = .empty,
        to topic: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: MQTTMessage.Properties = .init()
    ) async throws {
        try await publish(
            payload,
            to: topic,
            qos: qos,
            retain: retain,
            properties: properties
        ).get()
    }
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameters:
    ///   - payload: The payload of the message in the form of a string.
    ///   - topic: The topic for the message.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    public func publish(
        _ payload: String,
        to topic: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: MQTTMessage.Properties = .init()
    ) async throws {
        try await publish(
            payload,
            to: topic,
            qos: qos,
            retain: retain,
            properties: properties
        ).get()
    }
    
    // MARK: - Subscriptions
    
    /// Subscribes to one or more topics on the broker.
    /// - Parameters:
    ///   - subscriptions: An array of `MQTTSubscription`s indicating what to subscribe to.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An array of `MQTTSubscriptionResult`s indicating the results for each `MQTTSubscription`.
    @discardableResult
    public func subscribe(
        to subscriptions: [MQTTSubscription],
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) async throws -> MQTTSubscribeResponse {
        return try await subscribe(
            to: subscriptions,
            identifier: identifier,
            userProperties: userProperties
        ).get()
    }
    
    /// Subscribes to a topic with a given QoS.
    /// - Parameters:
    ///   - topicFilter: The topic filter to subscribe to.
    ///   - qos: The QoS level with which to subscribe. The default value is `.atMostOnce`.
    ///   - options: Additional subscription options for a 5.0 MQTT broker.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: The `MQTTSubscriptionResult` indicating the result of the subscription.
    @discardableResult
    public func subscribe(
        to topicFilter: String,
        qos: MQTTQoS = .atMostOnce,
        options: MQTTSubscription.Options = .init(),
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) async throws -> MQTTSingleSubscribeResponse {
        return try await subscribe(
            to: topicFilter,
            qos: qos,
            options: options,
            identifier: identifier,
            userProperties: userProperties
        ).get()
    }
    
    /// Subscribes to one or more topics with a given QoS level.
    /// - Parameters:
    ///   - topicFilters: The topic filters to subscribe to.
    ///   - qos: The QoS level with which to subscribe. The default value is `.atMostOnce`.
    ///   - options: Additional subscription options for a 5.0 MQTT broker.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: The `MQTTSubscriptionResult` indicating the result of the subscription.
    @discardableResult
    public func subscribe(
        to topicFilters: [String],
        qos: MQTTQoS = .atMostOnce,
        options: MQTTSubscription.Options = .init(),
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) async throws -> MQTTSubscribeResponse {
        return try await subscribe(
            to: topicFilters,
            qos: qos,
            options: options,
            identifier: identifier,
            userProperties: userProperties
        ).get()
    }
    
    /// Unsubscribe from one or more topics.
    /// - Parameters:
    ///   - topicFilters: The topic filters to unsubscribe from.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: The `MQTTUnsubscribeResponse` indicating the result of unsubscribing.
    @discardableResult
    func unsubscribe(
        from topicFilters: [String],
        userProperties: [MQTTUserProperty] = []
    ) async throws -> MQTTUnsubscribeResponse {
        return try await unsubscribe(
            from: topicFilters,
            userProperties: userProperties
        ).get()
    }
    
    /// Unsubscribe from a topic.
    /// - Parameters:
    ///   - topicFilter: The topic filter to unsubscribe from.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: The `MQTTUnsubscribeResponse` indicating the result of unsubscribing.
    @discardableResult
    public func unsubscribe(
        from topicFilter: String,
        userProperties: [MQTTUserProperty] = []
    ) async throws -> MQTTSingleUnsubscribeResponse {
        return try await unsubscribe(
            from: topicFilter,
            userProperties: userProperties
        ).get()
    }
    
    // MARK: - Re-authenticate
    
    /// Performs re-authentication with the broker.
    ///
    /// When performing re-authentication, the same authentication method should be used that was
    /// used for connecting with the broker in the first place.
    /// - Parameters:
    ///   - handler: The authentication handler to use.
    ///   - timeout: The time to wait for an authentication response from the broker. The default value is `5` seconds.
    public func reAuthenticate(
        using handler: MQTTAuthenticationHandler,
        timeout: TimeAmount = .seconds(5)
    ) async throws {
        try await reAuthenticate(
            using: handler,
            timeout: timeout
        ).get()
    }
    
    // MARK: - Async Sequence
    
    /// An async sequence for iterating over received messages from the broker.
    public var messages: AsyncStream<MQTTMessage> {
        AsyncStream { continuation in
            let cancellable = self.whenMessage {
                continuation.yield($0)
            }
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }
    
    /// An async sequence for iterating over received messages from the broker to a specific topic.
    /// - Parameter topic: The topic to receive messages for.
    public func messages(forTopic topic: String) -> AsyncFilterSequence<AsyncStream<MQTTMessage>> {
        return messages.filter {
            $0.topic == topic
        }
    }
    
    /// An async sequence for iterating over received messages from the broker to a specific subscription identifier.
    /// - Parameter identifier: The subscription identifier to receive messages for.
    public func messages(forIdentifier identifier: Int) -> AsyncFilterSequence<AsyncStream<MQTTMessage>> {
        return messages.filter {
            $0.properties.subscriptionIdentifiers.contains(identifier)
        }
    }
}

#endif
