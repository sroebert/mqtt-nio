import NIO

extension MQTTPacket {
    struct SubAck: MQTTPacketInboundType {
        
        // MARK: - Properties
        
        var packetId: UInt16
        var results: [MQTTSubscriptionResult]
        
        // MARK: - MQTTPacketOutboundType
        
        static func parse(from packet: inout MQTTPacket) throws -> MQTTPacket.SubAck {
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTConnectionError.protocol("Missing packet identifier")
            }
            
            var results: [MQTTSubscriptionResult] = []
            while let resultCode = packet.data.readInteger(as: UInt8.self) {
                switch resultCode {
                case 0x00:
                    results.append(.success(.atMostOnce))
                case 0x01:
                    results.append(.success(.atLeastOnce))
                case 0x02:
                    results.append(.success(.exactlyOnce))
                case 0x80:
                    results.append(.failure)
                default:
                    throw MQTTConnectionError.protocol("Invalid subscription result code")
                }
            }
            
            return SubAck(
                packetId: packetId,
                results: results
            )
        }
    }
}
