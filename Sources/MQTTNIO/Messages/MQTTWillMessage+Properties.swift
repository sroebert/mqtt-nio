import NIO

extension MQTTWillMessage {
    /// The message properties to with the message to a 5.0 MQTT broker.
    public struct Properties {
        
        /// The delay the broker will wait before sending the will message. During this interval, the client can reconnect without
        /// cleaning the session in order to avoid sending the will message. If `nil` the will message will be sent immediately.
        public var delayInterval: TimeAmount?
        
        /// Indicates the interval after which the message expires or `nil` if it does not expire.
        public var expiryInterval: TimeAmount?
        
        /// Optional configuration to indicate that this message is a request.
        public var requestConfiguration: MQTTRequestConfiguration?
        
        /// Additional user properties to send with this message.
        public var userProperties: [MQTTUserProperty]
        
        /// Creates a `MQTTMessage.Properties`.
        /// - Parameters:
        ///   - delayInterval: he delay the broker will wait before sending the will message. The default value is `nil`
        ///   - expiryInterval: Indicates the interval after which the message expires or `nil` if it does not expire. The default value is `nil`.
        ///   - topicAlias: The topic alias to use. The default value is `nil`.
        ///   - requestConfiguration: Optional configuration to indicate that this message is a request. The default value is `nil`.
        ///   - userProperties: Additional user properties to send with this message. The default value is an empty array.
        public init(
            delayInterval: TimeAmount? = nil,
            expiryInterval: TimeAmount? = nil,
            requestConfiguration: MQTTRequestConfiguration? = nil,
            userProperties: [MQTTUserProperty] = []
        ) {
            self.delayInterval = delayInterval
            self.expiryInterval = expiryInterval
            self.requestConfiguration = requestConfiguration
            self.userProperties = userProperties
        }
    }
}
