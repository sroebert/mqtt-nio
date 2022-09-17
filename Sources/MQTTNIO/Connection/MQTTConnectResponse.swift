import NIO

/// Response returned when the `MQTTClient` is connected to a broker.
public struct MQTTConnectResponse: Equatable, MQTTSendable {
    
    /// Indicates whether there is a session present for the client on the broker.
    public var isSessionPresent: Bool
    
    /// The session expiry set for the current connection.
    ///
    /// The server can have set a different expiry than requested when connecting,
    /// this is the final value for the current connection.
    public var sessionExpiry: MQTTConfiguration.SessionExpiry
    
    /// The keep alive interval for the current connection.
    ///
    /// The server can have set a different keep alive than requested when connecting,
    /// this is the final value for the current connection.
    public var keepAliveInterval: TimeAmount
    
    /// When sending an empty client identifier, the server can set a client identifier for the client.
    ///
    /// This value is the final client identifier which was assigned to the client.
    public var assignedClientIdentifier: String
    
    /// The user properties send with the connection acknowledgement from the broker.
    public var userProperties: [MQTTUserProperty]
    
    /// A string which should be used as the basis for creating a response topic.
    ///
    /// The way in which the client creates a response topic from the response Information is not defined.
    public var responseInformation: String?
    
    /// Information on the configuration of the broker.
    ///
    /// This configuration indicates what functionality is available.
    public var brokerConfiguration: MQTTBrokerConfiguration
}

/// Information received when connecting with the broker, indicating the capabilities of the broker.
public struct MQTTBrokerConfiguration: Equatable, MQTTSendable {
    
    /// The maximum QoS value allowed by the server.
    ///
    /// When sending messages with a higher QoS value, the client will automatically lower it to this maximum.
    public var maximumQoS: MQTTQoS = .exactlyOnce
    
    /// Indicates whether the retain option for messages is available.
    ///
    /// When sending messages with retain set to `true`, the client will automatically set it to `false` if it is not available on the broker.
    public var isRetainAvailable: Bool = true
    
    /// The maximum packet size that the broker allows. If `nil` it indicates there is no maximum other than what the MQTT protocol allows.
    ///
    /// When sending messages that result in a higher packet size, instead of sending the packet, the client will return a `MQTTProtocolError` with code `.tooLarge`.
    public var maximumPacketSize: Int?
    
    /// Indicates whether the broker supports wildcard subscriptions.
    ///
    /// If this property is `false`, when trying to subscribe to a topic filter including a wildcard, instead of subscribing, the client will return a `MQTTSubscribeError.subscriptionWildcardsNotSupported` error.
    public var isWildcardSubscriptionAvailable: Bool = true
    
    /// Indicates whether the broker supports subscription identifiers.
    ///
    /// If this property is `false`, when trying to subscribe with a subscription identifier, instead of subscribing, the client will return a `MQTTSubscribeError.subscriptionIdentifiersNotSupported` error.
    public var isSubscriptionIdentifierAvailable: Bool = true
    
    /// Indicates whether the broker supports shared subscriptions.
    ///
    /// If this property is `false`, when trying to subscribe to a shared subscription, instead of subscribing, the client will return a `MQTTSubscribeError.sharedSubscriptionsNotSupported` error.
    public var isSharedSubscriptionAvailable: Bool = true
}
