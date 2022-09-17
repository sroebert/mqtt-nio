import NIO

/// Struct representing an MQTT message being send by the broker under certain conditions when a client disconnects.
public struct MQTTWillMessage: MQTTSendable {
    /// The topic of the message.
    public var topic: String
    
    /// The optional payload of the message as bytes.
    ///
    /// Most frequently this message will be an UTF-8 string, but it depends on the context.
    public var payload: MQTTPayload
    
    /// The QoS level with which this message will be sent or was sent.
    public var qos: MQTTQoS
    
    /// Indicating whether this message will be retained by the broker.
    ///
    /// If retained, it will be sent to a client as soon as they subscribe for the topic of the message.
    public var retain: Bool
    
    /// The message properties to send when publishing to a 5.0 MQTT broker.
    public var properties: Properties
    
    /// Creates an `MQTTWillMessage`.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The payload of the message. The default is `.empty`.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    public init(
        topic: String,
        payload: MQTTPayload = .empty,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: Properties = Properties()
    ) {
        self.topic = topic
        self.payload = payload
        self.qos = qos
        self.retain = retain
        self.properties = properties
    }
    
    /// Creates an `MQTTWillMessage`.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The payload of the message in the form of a string.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    public init(
        topic: String,
        payload: String?,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: Properties = Properties()
    ) {
        self.init(
            topic: topic,
            payload: payload.map { .string($0) } ?? .empty,
            qos: qos,
            retain: retain,
            properties: properties
        )
    }
}
