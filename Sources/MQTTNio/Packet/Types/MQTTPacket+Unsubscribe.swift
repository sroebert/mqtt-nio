import NIO

extension MQTTPacket {
    struct Unsubscribe: MQTTPacketOutboundType {
        
        // MARK: - Properties
        
        var topics: [String]
        var packetId: UInt16
        
        // MARK: - MQTTPacketOutboundType
        
        func serialize() throws -> MQTTPacket {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            
            buffer.writeInteger(packetId)
            
            for topic in topics {
                try buffer.writeMQTTString(topic, "Topic name")
            }
            
            return MQTTPacket(
                kind: .unsubscribe,
                fixedHeaderData: 0b0010,
                data: buffer
            )
        }
    }
}
