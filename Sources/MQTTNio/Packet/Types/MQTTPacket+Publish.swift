import NIO

extension MQTTPacket {
    struct Publish: MQTTPacketDuplexType {
        
        // MARK: - Properties
        
        var message: MQTTMessage
        var packetId: UInt16? = nil
        var isDuplicate: Bool = false
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(from packet: inout MQTTPacket) throws -> MQTTPacket.Publish {
            let flags = Flags(rawValue: packet.fixedHeaderData)
            
            let topic = try packet.data.readMQTTString("Topic")
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTConnectionError.protocol("Missing packet identifier")
            }
            
            let payload: ByteBuffer?
            if packet.data.readableBytes > 0 {
                var buffer = ByteBufferAllocator().buffer(capacity: 0)
                buffer.writeBuffer(&packet.data)
                payload = buffer
            } else {
                payload = nil
            }
            
            return Publish(
                message: MQTTMessage(
                    topic: topic,
                    payload: payload,
                    qos: flags.qos,
                    retain: flags.contains(.retain)
                ),
                packetId: packetId,
                isDuplicate: flags.contains(.dup)
            )
        }
        
        func serialize(using idProvider: MQTTPacketOutboundIDProvider) throws -> MQTTPacket {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            
            try buffer.writeMQTTString(message.topic, "Topic")
            
            let packetId = self.packetId ?? idProvider.getNextPacketId()
            buffer.writeInteger(packetId)
            
            if var payload = message.payload {
                buffer.writeBuffer(&payload)
            }
            
            let flags = generateFlags()
            return MQTTPacket(kind: .publish, fixedHeaderData: flags.rawValue, data: buffer)
        }
        
        // MARK: - Utils
        
        private func generateFlags() -> Flags {
            var flags: Flags = []
            
            if message.retain {
                flags.insert(.retain)
            }
            
            switch message.qos {
            case .atMostOnce:
                break
            case .atLeastOnce:
                flags.insert(.qos1)
            case .exactlyOnce:
                flags.insert(.qos2)
            }
            
            if isDuplicate {
                flags.insert(.dup)
            }
            
            return flags
        }
    }
}

extension MQTTPacket.Publish {
    struct Flags: OptionSet {
        let rawValue: UInt8

        static let retain   = Flags(rawValue: 1 << 0)
        static let qos1     = Flags(rawValue: 1 << 1)
        static let qos2     = Flags(rawValue: 1 << 2)
        static let dup      = Flags(rawValue: 1 << 3)

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        var qos: MQTTMessage.QoS {
            if contains(.qos2) {
                return .exactlyOnce
            }
            if contains(.qos1) {
                return .atLeastOnce
            }
            return .atMostOnce
        }

        var description: String {
            return [
                "retain": contains(.retain),
                "qos1": contains(.qos1),
                "qos2": contains(.qos2),
                "dup": contains(.dup),
            ].description
        }
    }
}
