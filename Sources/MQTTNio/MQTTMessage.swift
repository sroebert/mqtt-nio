import NIO

public struct MQTTMessage {
    public var topic: String
    public var payload: ByteBuffer?
    public var qos: MQTTQoS
    public var retain: Bool
    
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
    
    public var stringValue: String? {
        guard var payload = payload else {
            return nil
        }
        return payload.readString(length: payload.readableBytes)
    }
}
