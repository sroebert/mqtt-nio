import NIO

extension MQTTMessage {
    /// The message properties to with the message to a 5.0 MQTT broker.
    public struct Properties {
        
        /// Indicates the interval after which the message expires or `nil` if it does not expire.
        public var expiryInterval: TimeAmount?
        
        /// When sending a message to a topic, by setting this value, the broker will set the given number
        /// to be an alias for the given topic. After this, any message can be send to the same topic, by simply
        /// using the topic alias and an empty topic. This shortens the message length for larger topics,
        /// making them more efficient.
        public var topicAlias: Int?
        
        /// Optional configuration to indicate that this message is a request.
        public var requestConfiguration: MQTTRequestConfiguration?
        
        /// Additional user properties to send with this message.
        public var userProperties: [MQTTUserProperty]
        
        /// If passed when subscribing for a topic, messages from the broker will include the passed subscription identifier.
        ///
        /// As there could be multiple overlapping subscriptions, it will be an array of identifiers.
        public var subscriptionIdentifiers: [Int]
        
        /// Creates a `MQTTMessage.Properties`.
        /// - Parameters:
        ///   - expiryInterval: Indicates the interval after which the message expires or `nil` if it does not expire. The default value is `nil`.
        ///   - topicAlias: The topic alias to use. The default value is `nil`.
        ///   - requestConfiguration: Optional configuration to indicate that this message is a request. The default value is `nil`.
        ///   - userProperties: Additional user properties to send with this message. The default value is an empty array.
        public init(
            expiryInterval: TimeAmount? = nil,
            topicAlias: Int? = nil,
            requestConfiguration: MQTTRequestConfiguration? = nil,
            userProperties: [MQTTUserProperty] = []
        ) {
            self.init(
                expiryInterval: expiryInterval,
                topicAlias: topicAlias,
                requestConfiguration: requestConfiguration,
                userProperties: userProperties,
                subscriptionIdentifiers: []
            )
        }
        
        init(
            expiryInterval: TimeAmount? = nil,
            topicAlias: Int? = nil,
            requestConfiguration: MQTTRequestConfiguration? = nil,
            userProperties: [MQTTUserProperty] = [],
            subscriptionIdentifiers: [Int]
        ) {
            self.expiryInterval = expiryInterval
            self.topicAlias = topicAlias
            self.requestConfiguration = requestConfiguration
            self.userProperties = userProperties
            self.subscriptionIdentifiers = subscriptionIdentifiers
        }
    }
}
