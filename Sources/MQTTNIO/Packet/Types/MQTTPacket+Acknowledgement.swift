import NIO

extension MQTTPacket {
    struct Acknowledgement: MQTTPacketDuplexType {
        
        // MARK: - Kind
        
        enum Kind: UInt16, CustomStringConvertible {
            case pubAck
            case pubRec
            case pubRel
            case pubComp
            
            var description: String {
                switch self {
                case .pubAck:
                    return "Publish Acknowledgement"
                case .pubRec:
                    return "Publish Received"
                case .pubRel:
                    return "Publish Release"
                case .pubComp:
                    return "Publish Complete"
                }
            }
        }
        
        // MARK: - Properties
        
        private static let relFixedHeaderData: UInt8 = 0b0010
        
        var kind: Kind
        var packetId: UInt16
        var reasonCode: ReasonCode = .success
        var reasonString: String?
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            let kind = try parseKind(from: packet)
            
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTProtocolError("Missing packet identifier")
            }
            
            let reasonCode: ReasonCode
            let reasonString: String?
            if version >= .version5 {
                guard let reasonCodeValue = packet.data.readInteger(as: UInt8.self) else {
                    throw MQTTProtocolError("Invalid acknowledgement packet structure")
                }
                
                guard let parsedReasonCode = ReasonCode(rawValue: reasonCodeValue, kind: kind) else {
                    throw MQTTProtocolError("Invalid acknowledgement reason code")
                }
                
                reasonCode = parsedReasonCode
                
                let properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
                reasonString = properties.reasonString
            } else {
                reasonCode = .success
                reasonString = nil
            }
            
            return Acknowledgement(
                kind: kind,
                packetId: packetId,
                reasonCode: reasonCode,
                reasonString: reasonString
            )
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 2)
            buffer.writeInteger(packetId)
            
            if version > .version5 {
                buffer.writeInteger(reasonCode.mqttReasonCode.rawValue)
                
                var properties = MQTTProperties()
                properties.reasonString = reasonString
                try properties.serialize(to: &buffer)
            }
            
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
                    throw MQTTProtocolError("Invalid PubRel fixed header data")
                }
                return .pubRel
                
            case .pubComp:
                return .pubComp
                
            default:
                throw MQTTProtocolError("Invalid packet type '\(packet.kind.value)'")
            }
        }
        
        @MQTTPropertiesParserBuilder
        private static var propertiesParser: MQTTPropertiesParser {
            \.$reasonString
            \.$userProperties
        }
    }
}

extension MQTTPacket.Acknowledgement {
    enum ReasonCode {
        case success
        case noMatchingSubscribers
        case unspecifiedError
        case implementationSpecificError
        case notAuthorized
        case topicNameInvalid
        case packetIdentifierInUse
        case packetIdentifierNotFound
        case quotaExceeded
        case payloadFormatInvalid
        
        init?(rawValue: UInt8, kind: Kind) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch kind {
            case .pubAck, .pubRec:
                switch reasonCode {
                case .success: self = .success
                case .noMatchingSubscribers: self = .noMatchingSubscribers
                case .unspecifiedError: self = .unspecifiedError
                case .implementationSpecificError: self = .implementationSpecificError
                case .notAuthorized: self = .notAuthorized
                case .topicNameInvalid: self = .topicNameInvalid
                case .packetIdentifierInUse: self = .packetIdentifierInUse
                case .quotaExceeded: self = .quotaExceeded
                case .payloadFormatInvalid: self = .payloadFormatInvalid
                    
                default:
                    return nil
                }
                
            case .pubRel, .pubComp:
                switch reasonCode {
                case .success: self = .success
                case .packetIdentifierNotFound: self = .packetIdentifierNotFound
                    
                default:
                    return nil
                }
            }
        }
        
        var mqttReasonCode: MQTTReasonCode {
            switch self {
            case .success: return .success
            case .noMatchingSubscribers: return .noMatchingSubscribers
            case .unspecifiedError: return .unspecifiedError
            case .implementationSpecificError: return .implementationSpecificError
            case .notAuthorized: return .notAuthorized
            case .topicNameInvalid: return .topicNameInvalid
            case .packetIdentifierInUse: return .packetIdentifierInUse
            case .packetIdentifierNotFound: return .packetIdentifierNotFound
            case .quotaExceeded: return .quotaExceeded
            case .payloadFormatInvalid: return .payloadFormatInvalid
            }
        }
    }
}
