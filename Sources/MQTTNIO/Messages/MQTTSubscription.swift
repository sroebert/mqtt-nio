/// This  struct represents a subscription that can be made with an MQTT broker.
public struct MQTTSubscription: MQTTSendable {
    /// The topic filter to which the client wants to subscribe.
    public var topicFilter: String
    
    /// The QoS level with which the user wants to subscribe.
    public var qos: MQTTQoS
    
    /// Additional subscription options for a 5.0 MQTT broker.
    public var options: Options
    
    /// Creates an `MQTTSubscription`.
    /// - Parameters:
    ///   - topicFilter: The topic filter for the subscription.
    ///   - qos: The QoS level with which to subscribe.
    public init(
        topicFilter: String,
        qos: MQTTQoS = .atMostOnce,
        options: Options = Options()
    ) {
        self.topicFilter = topicFilter
        self.qos = qos
        self.options = options
    }
}

extension MQTTSubscription {
    /// Additional options that can be set for a subscription with a 5.0 MQTT broker.
    public struct Options: MQTTSendable {
        
        /// Indicates whether messages send from this client to the subscribed topic should not be received by this client.
        public var noLocalMessages: Bool
        
        /// Indicates if the retain flag should be kept by the broker when sending retained messages to this client for this subscription.
        public var retainAsPublished: Bool
        
        /// Indicates the way retained messages are handled for this subscription.
        public var retainedMessageHandling: RetainedMessageHandling
        
        /// Creates an `MQTTSubscription.Options`.
        /// - Parameters:
        ///   - noLocalMessages: Indicates whether messages send from this client to the subscribed topic should not be received by this client. The default value is `false`.
        ///   - retainAsPublished: Indicates if the retain flag should be kept by the broker when sending retained messages to this client for this subscription. The default value is `false`.
        ///   - retainedMessageHandling: Indicates the way retained messages are handled for this subscription. The default value is `.sendOnSubscribe`
        public init(
            noLocalMessages: Bool = false,
            retainAsPublished: Bool = false,
            retainedMessageHandling: RetainedMessageHandling = .sendOnSubscribe
        ) {
            self.noLocalMessages = noLocalMessages
            self.retainAsPublished = retainAsPublished
            self.retainedMessageHandling = retainedMessageHandling
        }
    }
    
    /// Indicates how retained messages are handled for a subscription.
    public enum RetainedMessageHandling: MQTTSendable {
        /// Retained messages will be send at the time of subscribing.
        case sendOnSubscribe
        /// Retained messages will be send at the time of subscribing if the subscription does not currently exist.
        case sendOnSubscribeIfNotExists
        /// Retained messages are not send when subscribing.
        case doNotSend
    }
}

/// The response returned from the broker when subscribing to a single topic.
public struct MQTTSingleSubscribeResponse: MQTTSendable {
    /// The result for the subscription.
    public var result: MQTTSubscriptionResult
    
    /// User properties send from the broker with this response.
    public var userProperties: [MQTTUserProperty]
    
    /// Optional reason string representing the reason associated with this response.
    public var reasonString: String?
}

/// The response returned from the broker when subscribing.
public struct MQTTSubscribeResponse: MQTTSendable {
    /// The results for each topic the client tried to subscribe to.
    public var results: [MQTTSubscriptionResult]
    
    /// User properties send from the broker with this response.
    public var userProperties: [MQTTUserProperty]
    
    /// Optional reason string representing the reason associated with this response.
    public var reasonString: String?
}

/// The result returned from the broker for each topic when subscribing, indicating the result.
///
/// For each `MQTTSubscription` trying to subscribe to, an `MQTTSubscriptionResult` will be returned from the broker.
public enum MQTTSubscriptionResult: Equatable, MQTTSendable {
    /// Succesfully subscribed, with the given QoS level and optional user properties.
    case success(MQTTQoS)
    
    /// Failed to subscribe with a given reason.
    case failure(ServerErrorReason)
}

extension MQTTSubscriptionResult {
    /// The reason returned from the server, indicating why the subscription failed.
    public enum ServerErrorReason: MQTTSendable {
        /// The server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
        case unspecifiedError
        
        /// The data that was send is valid but is not accepted by the server.
        case implementationSpecificError
        
        /// The user is not authorized to perform this operation.
        case notAuthorized
        
        /// The subscription topic is not accepted.
        case topicFilterInvalid
        
        /// The packet identifier send was already in use.
        case packetIdentifierInUse
        
        /// An implementation or administrative imposed limit has been exceeded.
        case quotaExceeded
        
        /// The server does not support shared subscriptions for this client.
        case sharedSubscriptionsNotSupported
        
        /// The server does not support subscription identifiers.
        case subscriptionIdentifiersNotSupported
        
        /// The Server does not support wildcard subscriptions.
        case wildcardSubscriptionsNotSupported
    }
}
