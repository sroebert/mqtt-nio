import NIO

/// Struct representing an MQTT message being send from or to the `MQTTClient`.
public struct MQTTMessage {
    /// The topic of the message.
    public var topic: String
    
    /// The optional payload of the message as bytes.
    ///
    /// Most frequently this message will be an UTF-8 string, but it depends on the context.
    public var payload: ByteBuffer?
    
    /// The QoS level with which this message will be send or was send.
    public var qos: MQTTQoS
    
    /// Indicating whether this message will be retained by the broker.
    ///
    /// If retained, it will be send to a client as soon as they subscribe for the topic of the message.
    public var retain: Bool
    
    /// Creates an `MQTTMessage`.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The optional payload of the message. The default is `nil`.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    public init(
        topic: String,
        payload: ByteBuffer? = nil,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false) {
        
        self.topic = topic
        self.payload = payload
        self.qos = qos
        self.retain = retain
    }
    
    /// Creates an `MQTTMessage`.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The payload of the message in the form of a string.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    public init(
        topic: String,
        payload: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false) {
        
        self.topic = topic
        
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString(payload)
        self.payload = buffer
        
        self.qos = qos
        self.retain = retain
    }
    
    /// Optional string value created from the payload of this message.
    public var payloadString: String? {
        guard var payload = payload else {
            return nil
        }
        return payload.readString(length: payload.readableBytes)
    }
}
