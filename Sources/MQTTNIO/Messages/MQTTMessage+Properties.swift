#if os(macOS) && compiler(<5.7.1)
@preconcurrency import Foundation
#else
import Foundation
#endif
import NIO

extension MQTTMessage {
    /// The message properties to with the message to a 5.0 MQTT broker.
    public struct Properties: MQTTSendable {
        
        /// Indicates the interval after which the message expires or `nil` if it does not expire.
        public var expiryInterval: TimeAmount?
        
        /// The response topic for the response on this request.
        ///
        /// If set, this message is identified as a request. If `correlationData` is set, it should be set on the response message send to this topic.
        public var responseTopic: String?
        
        /// Optional data that should be sent with the response message to a request.
        public var correlationData: Data?
        
        /// Additional user properties to send with this message.
        public var userProperties: [MQTTUserProperty]
        
        /// If passed when subscribing for a topic, messages from the broker will include the passed subscription identifier.
        ///
        /// As there could be multiple overlapping subscriptions, it will be an array of identifiers.
        public var subscriptionIdentifiers: [Int]
        
        /// Creates a `MQTTMessage.Properties`.
        /// - Parameters:
        ///   - expiryInterval: Indicates the interval after which the message expires or `nil` if it does not expire. The default value is `nil`.
        ///   - responseTopic: The response topic for the response on this request. The default is `nil`, indicating this is not a request.
        ///   - correlationData: Optional data that should be sent with the response message to a request. The default value is `nil`.
        ///   - userProperties: Additional user properties to send with this message. The default value is an empty array.
        public init(
            expiryInterval: TimeAmount? = nil,
            responseTopic: String? = nil,
            correlationData: Data? = nil,
            userProperties: [MQTTUserProperty] = []
        ) {
            self.init(
                expiryInterval: expiryInterval,
                responseTopic: responseTopic,
                correlationData: correlationData,
                userProperties: userProperties,
                subscriptionIdentifiers: []
            )
        }
        
        init(
            expiryInterval: TimeAmount? = nil,
            responseTopic: String? = nil,
            correlationData: Data? = nil,
            userProperties: [MQTTUserProperty] = [],
            subscriptionIdentifiers: [Int]
        ) {
            self.expiryInterval = expiryInterval
            self.responseTopic = responseTopic
            self.correlationData = correlationData
            self.userProperties = userProperties
            self.subscriptionIdentifiers = subscriptionIdentifiers
        }
    }
}
