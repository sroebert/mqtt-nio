/// This  struct represents a subscription that can be made with an MQTT broker.
public struct MQTTSubscription {
    /// The topic to which the client wants to subscribe.
    public var topic: String
    
    /// The QoS level with which the user wants to subscribe.
    public var qos: MQTTQoS
    
    /// Additional subscription options for a 5.0 MQTT broker.
    public var options: Options
    
    /// Creates an `MQTTSubscription`.
    /// - Parameters:
    ///   - topic: The topic for the subscription.
    ///   - qos: The QoS level with which to subscribe.
    public init(
        topic: String,
        qos: MQTTQoS = .atMostOnce,
        options: Options = Options()
    ) {
        self.topic = topic
        self.qos = qos
        self.options = options
    }
}

extension MQTTSubscription {
    /// Additional options that can be set for a subscription with a 5.0 MQTT broker.
    public struct Options {
        
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
    public enum RetainedMessageHandling {
        /// Retained messages will be send at the time of subscribing.
        case sendOnSubscribe
        /// Retained messages will be send at the time of subscribing if the subscription does not currently exist.
        case sendOnSubscribeIfNotExists
        /// Retained messages are not send when subscribing.
        case doNotSend
    }
}

/// The result returned from the broker when subscribing, indicating the result.
///
/// For each `MQTTSubscription` trying to subscribe to, an `MQTTSubscriptionResult` will be returned from the broker.
public enum MQTTSubscriptionResult: Equatable {
    /// Succesfully subscribed, with the given QoS level.
    case success(MQTTQoS)
    /// Failed to subscribe.
    case failure
}
