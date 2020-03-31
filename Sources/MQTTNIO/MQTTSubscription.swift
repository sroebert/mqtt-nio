public struct MQTTSubscription {
    public var topic: String
    public var qos: MQTTQoS
    
    public init(topic: String, qos: MQTTQoS = .atMostOnce) {
        self.topic = topic
        self.qos = qos
    }
}

public enum MQTTSubscriptionResult {
    case success(MQTTQoS)
    case failure
}
