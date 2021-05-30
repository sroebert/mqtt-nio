import NIO

extension MQTTPacket {
    struct Subscribe: MQTTPacketOutboundType {
        
        // MARK: - Vars
        
        private let data: Data
        
        // MARK: - Init
        
        init(
            subscriptions: [MQTTSubscription],
            subscriptionIdentifier: Int?,
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            data = Data(
                subscriptions: subscriptions,
                subscriptionIdentifier: subscriptionIdentifier,
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
                properties.subscriptionIdentifier = data.subscriptionIdentifier
                properties.userProperties = data.userProperties
                try properties.serialize(to: &buffer)
            }
            
            for subscription in data.subscriptions {
                try buffer.writeMQTTString(subscription.topicFilter, "Topic filter")
                
                let options = optionsValue(for: subscription, version: version)
                buffer.writeInteger(options)
            }
            
            return MQTTPacket(
                kind: .subscribe,
                fixedHeaderData: 0b0010,
                data: buffer
            )
        }
        
        // MARK: - Utils
        
        func size(version: MQTTProtocolVersion) -> Int {
            var dataSize = 0
            
            dataSize += MemoryLayout<UInt16>.size
            
            if version >= .version5 {
                var properties = MQTTProperties()
                properties.subscriptionIdentifier = data.subscriptionIdentifier
                properties.userProperties = data.userProperties
                dataSize += properties.size()
            }
            
            for subscription in data.subscriptions {
                dataSize += ByteBuffer.sizeForMQTTString(subscription.topicFilter)
                dataSize += MemoryLayout<UInt8>.size
            }
            
            return dataSize
        }
        
        private func optionsValue(
            for subscription: MQTTSubscription,
            version: MQTTProtocolVersion
        ) -> UInt8 {
            guard version >= .version5 else {
                return subscription.qos.rawValue
            }
            
            let retainHandlingValue: UInt8
            switch subscription.options.retainedMessageHandling {
            case .sendOnSubscribe:
                retainHandlingValue = 0b00000000
            case .sendOnSubscribeIfNotExists:
                retainHandlingValue = 0b00010000
            case .doNotSend:
                retainHandlingValue = 0b00100000
            }
            
            return subscription.qos.rawValue |
                (subscription.options.noLocalMessages ? 0b00000100 : 0) |
                (subscription.options.retainAsPublished ? 0b00001000 : 0) |
                retainHandlingValue
        }
    }
}

extension MQTTPacket.Subscribe {
    // Wrapper to avoid heap allocations when added to NIOAny
    fileprivate class Data {
        let subscriptions: [MQTTSubscription]
        let subscriptionIdentifier: Int?
        let userProperties: [MQTTUserProperty]
        let packetId: UInt16
        
        init(
            subscriptions: [MQTTSubscription],
            subscriptionIdentifier: Int?,
            userProperties: [MQTTUserProperty],
            packetId: UInt16
        ) {
            self.subscriptions = subscriptions
            self.subscriptionIdentifier = subscriptionIdentifier
            self.userProperties = userProperties
            self.packetId = packetId
        }
    }
}
