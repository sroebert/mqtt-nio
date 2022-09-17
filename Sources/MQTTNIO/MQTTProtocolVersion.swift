
/// The protocol version to use when connecting to a broker.
public enum MQTTProtocolVersion: UInt8, Comparable, CaseIterable, MQTTSendable {
    /// MQTT version 3.1.1.
    case version3_1_1 = 0x04
    
    /// MQTT version 5.
    case version5 = 0x05
    
    public static func < (lhs: MQTTProtocolVersion, rhs: MQTTProtocolVersion) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
