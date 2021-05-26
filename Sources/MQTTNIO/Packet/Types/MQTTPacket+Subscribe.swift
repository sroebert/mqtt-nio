import NIO

extension MQTTPacket {
    struct Subscribe: MQTTPacketOutboundType {
        
        // MARK: - Properties
        
        var subscriptions: [MQTTSubscription]
        var subscriptionIdentifier: Int?
        var userProperties: [MQTTUserProperty]
        
        var packetId: UInt16
        
        // MARK: - MQTTPacketOutboundType
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            
            buffer.writeInteger(packetId)
            
            if version >= .version5 {
                var properties = MQTTProperties()
                properties.subscriptionIdentifier = subscriptionIdentifier
                properties.userProperties = userProperties
                try properties.serialize(to: &buffer)
            }
            
            for subscription in subscriptions {
                try buffer.writeMQTTString(subscription.topic, "Topic name")
                
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
        
        private func optionsValue(
            for subscription: MQTTSubscription,
            version: MQTTProtocolVersion
        ) -> UInt8 {
            guard version > .version5 else {
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
