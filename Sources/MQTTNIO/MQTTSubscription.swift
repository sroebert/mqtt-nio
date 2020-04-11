/// This  struct represents a subscription that can be made with an MQTT broker.
public struct MQTTSubscription {
    /// The topic to which the client wants to subscribe.
    public var topic: String
    
    /// The QoS level with which the user wants to subscribe.
    public var qos: MQTTQoS
    
    /// Creates an `MQTTSubscription`.
    /// - Parameters:
    ///   - topic: The topic for the subscription.
    ///   - qos: The QoS level with which to subscribe.
    public init(topic: String, qos: MQTTQoS = .atMostOnce) {
        self.topic = topic
        self.qos = qos
    }
}

/// The result returned from the broker when subscribing, indicating the result.
///
/// For each `MQTTSubscription` trying to subscribe to, an `MQTTSubscriptionResult` will be returned from the broker.
public enum MQTTSubscriptionResult {
    /// Succesfully subscribed, with the given QoS level.
    case success(MQTTQoS)
    /// Failed to subscribe.
    case failure
}
