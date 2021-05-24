import NIO

extension MQTTPacket {
    struct Disconnect: MQTTPacketOutboundType {
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            return MQTTPacket(kind: .disconnect)
        }
    }
}
