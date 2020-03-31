import NIO

extension MQTTPacket {
    struct UnsubAck: MQTTPacketInboundType {
        
        // MARK: - Properties
        
        var packetId: UInt16
        
        // MARK: - MQTTPacketOutboundType
        
        static func parse(from packet: inout MQTTPacket) throws -> MQTTPacket.UnsubAck {
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTConnectionError.protocol("Missing packet identifier")
            }
            return UnsubAck(packetId: packetId)
        }
    }
}
