import NIO

extension MQTTMessage {
    /// The message properties to with the message to a 5.0 MQTT broker.
    public struct Properties {
        
        /// Indicates the interval after which the message expires or `nil` if it does not expire.
        public var expiryInterval: TimeAmount?
        
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
        ///   - requestConfiguration: Optional configuration to indicate that this message is a request. The default value is `nil`.
        ///   - userProperties: Additional user properties to send with this message. The default value is an empty array.
        public init(
            expiryInterval: TimeAmount? = nil,
            requestConfiguration: MQTTRequestConfiguration? = nil,
            userProperties: [MQTTUserProperty] = []
        ) {
            self.init(
                expiryInterval: expiryInterval,
                requestConfiguration: requestConfiguration,
                userProperties: userProperties,
                subscriptionIdentifiers: []
            )
        }
        
        init(
            expiryInterval: TimeAmount? = nil,
            requestConfiguration: MQTTRequestConfiguration? = nil,
            userProperties: [MQTTUserProperty] = [],
            subscriptionIdentifiers: [Int]
        ) {
            self.expiryInterval = expiryInterval
            self.requestConfiguration = requestConfiguration
            self.userProperties = userProperties
            self.subscriptionIdentifiers = subscriptionIdentifiers
        }
    }
}
