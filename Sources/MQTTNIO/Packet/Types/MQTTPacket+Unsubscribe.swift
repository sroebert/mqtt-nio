import NIO

extension MQTTPacket {
    struct Unsubscribe: MQTTPacketOutboundType {
        
        // MARK: - Vars
        
        private let data: Data
        
        // MARK: - Init
        
        init(
            topicFilters: [String],
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            data = Data(
                topicFilters: topicFilters,
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
            
            for topicFilter in data.topicFilters {
                try buffer.writeMQTTString(topicFilter, "Topic filter")
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
        let topicFilters: [String]
        let userProperties: [MQTTUserProperty]
        let packetId: UInt16
        
        init(
            topicFilters: [String],
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            self.topicFilters = topicFilters
            self.userProperties = userProperties
            self.packetId = packetId
        }
    }
}
