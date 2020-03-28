import NIO

extension MQTTPacket {
    struct Disconnect: MQTTPacketOutboundType {
        func serialize() throws -> MQTTPacket {
            return MQTTPacket(kind: .disconnect)
        }
    }
}
