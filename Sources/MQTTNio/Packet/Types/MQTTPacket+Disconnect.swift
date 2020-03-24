import NIO

extension MQTTPacket {
    struct Disconnect: MQTTPacketOutboundType {
        func serialize(using idProvider: MQTTPacketOutboundIDProvider) throws -> MQTTPacket {
            return MQTTPacket(kind: .disconnect)
        }
    }
}
