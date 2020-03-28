import NIO

extension MQTTPacket {
    struct Acknowledgement: MQTTPacketDuplexType {
        
        // MARK: - Kind
        
        enum Kind: UInt16 {
            case pubAck
            case pubRec
            case pubRel
            case pubComp
        }
        
        // MARK: - Properties
        
        private static let relFixedHeaderData: UInt8 = 0b0010
        
        var kind: Kind
        var packetId: UInt16
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(from packet: inout MQTTPacket) throws -> MQTTPacket.Acknowledgement {
            let kind = try parseKind(from: packet)
            
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTConnectionError.protocol("Missing packet identifier")
            }
            return Acknowledgement(kind: kind, packetId: packetId)
        }
        
        func serialize() throws -> MQTTPacket {
            var buffer = ByteBufferAllocator().buffer(capacity: 2)
            buffer.writeInteger(packetId)
            
            let packetKind: MQTTPacket.Kind
            var fixedHeaderData: UInt8 = 0
            
            switch kind {
            case .pubAck:
                packetKind = .pubAck
                
            case .pubRec:
                packetKind = .pubRec
                
            case .pubRel:
                packetKind = .pubRel
                fixedHeaderData = Self.relFixedHeaderData
                
            case .pubComp:
                packetKind = .pubComp
            }
            
            return MQTTPacket(
                kind: packetKind,
                fixedHeaderData: fixedHeaderData,
                data: buffer
            )
        }
        
        // MARK: - Utils
        
        private static func parseKind(from packet: MQTTPacket) throws -> Kind {
            switch packet.kind {
            case .pubAck:
                return .pubAck
                
            case .pubRec:
                return .pubRec
                
            case .pubRel:
                guard packet.fixedHeaderData == Self.relFixedHeaderData else {
                    throw MQTTConnectionError.protocol("Invalid PubRel fixed header data")
                }
                return .pubRel
                
            case .pubComp:
                return .pubComp
                
            default:
               throw MQTTConnectionError.protocol("Invalid packet kind")
            }
        }
    }
}
