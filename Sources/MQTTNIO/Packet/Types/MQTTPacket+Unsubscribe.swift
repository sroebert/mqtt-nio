import NIO

extension MQTTPacket {
    struct Unsubscribe: MQTTPacketOutboundType {
        
        // MARK: - Vars
        
        private let data: Data
        
        // MARK: - Init
        
        init(
            topics: [String],
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            data = Data(
                topics: topics,
                userProperties: userProperties,
                packetId: packetId
            )
        }
        
        // MARK: - MQTTPacketOutboundType
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            
            buffer.writeInteger(data.packetId)
            
            if version >= .version5 {
                var properties = MQTTProperties()
                properties.userProperties = data.userProperties
                try properties.serialize(to: &buffer)
            }
            
            for topic in data.topics {
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

extension MQTTPacket.Unsubscribe {
    // Wrapper to avoid heap allocations when added to NIOAny
    fileprivate class Data {
        let topics: [String]
        let userProperties: [MQTTUserProperty]
        let packetId: UInt16
        
        init(
            topics: [String],
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            self.topics = topics
            self.userProperties = userProperties
            self.packetId = packetId
        }
    }
}
