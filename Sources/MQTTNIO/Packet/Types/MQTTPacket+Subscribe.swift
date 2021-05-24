import NIO

extension MQTTPacket {
    struct Subscribe: MQTTPacketOutboundType {
        
        // MARK: - Properties
        
        var subscriptions: [MQTTSubscription]
        var packetId: UInt16
        
        // MARK: - MQTTPacketOutboundType
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            
            buffer.writeInteger(packetId)
            
            for subscription in subscriptions {
                try buffer.writeMQTTString(subscription.topic, "Topic name")
                buffer.writeInteger(subscription.qos.rawValue)
            }
            
            return MQTTPacket(
                kind: .subscribe,
                fixedHeaderData: 0b0010,
                data: buffer
            )
        }
    }
}
