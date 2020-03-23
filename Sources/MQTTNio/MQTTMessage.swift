import NIO

public struct MQTTMessage {
    public var topic: String
    public var payload: ByteBuffer?
    public var qos: QoS
    public var retain: Bool
    
    public var stringValue: String? {
        guard var payload = payload else {
            return nil
        }
        return payload.readString(length: payload.readableBytes)
    }
}

extension MQTTMessage {
    public enum QoS: Int {
        case atMostOnce = 0
        case atLeastOnce = 1
        case exactlyOnce = 2
    }
}
