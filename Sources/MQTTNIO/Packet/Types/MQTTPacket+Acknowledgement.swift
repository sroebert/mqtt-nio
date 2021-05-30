import NIO

extension MQTTPacket {
    struct Acknowledgement: MQTTPacketDuplexType {
        
        // MARK: - Vars
        
        var kind: Kind {
            return data.kind
        }
        
        var packetId: UInt16 {
            return data.packetId
        }
        
        var reasonCode: ReasonCode {
            return data.reasonCode
        }
        
        var reasonString: String? {
            return data.reasonString
        }
        
        var userProperties: [MQTTUserProperty] {
            return data.userProperties
        }
        
        private static let relFixedHeaderData: UInt8 = 0b0010
        
        private let data: Data
        
        // MARK: - Lifecycle
        
        private init(
            kind: Kind,
            packetId: UInt16,
            reasonCode: ReasonCode = .success,
            reasonString: String? = nil,
            userProperties: [MQTTUserProperty] = []
        ) {
            data = Data(
                kind: kind,
                packetId: packetId,
                reasonCode: reasonCode,
                reasonString: reasonString,
                userProperties: userProperties
            )
        }
        
        static func pubAck(
            packetId: UInt16,
            response: MQTTAcknowledgementResponse?
        ) -> Self {
            return self.init(
                kind: .pubAck,
                packetId: packetId,
                reasonCode: .init(response?.error?.code),
                reasonString: response?.error?.message,
                userProperties: response?.userProperties ?? []
            )
        }
        
        static func pubRel(
            packetId: UInt16,
            notFound: Bool = false
        ) -> Self {
            return self.init(
                kind: .pubRel,
                packetId: packetId,
                reasonCode: notFound ? .packetIdentifierNotFound : .success
            )
        }
        
        static func pubRec(
            packetId: UInt16,
            response: MQTTAcknowledgementResponse?
        ) -> Self {
            return self.init(
                kind: .pubRec,
                packetId: packetId,
                reasonCode: .init(response?.error?.code),
                reasonString: response?.error?.message,
                userProperties: response?.userProperties ?? []
            )
        }
        
        static func pubComp(
            packetId: UInt16,
            notFound: Bool = false
        ) -> Self {
            return self.init(
                kind: .pubComp,
                packetId: packetId,
                reasonCode: notFound ? .packetIdentifierNotFound : .success
            )
        }
        
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
            let userProperties: [MQTTUserProperty]
            if version >= .version5, let reasonCodeValue = packet.data.readInteger(as: UInt8.self) {
                guard let parsedReasonCode = ReasonCode(rawValue: reasonCodeValue, kind: kind) else {
                    throw MQTTProtocolError("Invalid acknowledgement reason code")
                }
                
                reasonCode = parsedReasonCode
                
                if packet.data.readableBytes > 0 {
                    let properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
                    reasonString = properties.reasonString
                    userProperties = properties.userProperties
                } else {
                    reasonString = nil
                    userProperties = []
                }
            } else {
                reasonCode = .success
                reasonString = nil
                userProperties = []
            }
            
            return Acknowledgement(
                kind: kind,
                packetId: packetId,
                reasonCode: reasonCode,
                reasonString: reasonString,
                userProperties: userProperties
            )
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            buffer.writeInteger(data.packetId)
            
            if version >= .version5 {
                if data.reasonCode != .success || reasonString != nil {
                    buffer.writeInteger(data.reasonCode.mqttReasonCode.rawValue)
                }
                
                if reasonString != nil {
                    var properties = MQTTProperties()
                    properties.reasonString = data.reasonString
                    try properties.serialize(to: &buffer)
                }
            }
            
            let packetKind: MQTTPacket.Kind
            var fixedHeaderData: UInt8 = 0
            
            switch data.kind {
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
                guard packet.fixedHeaderData == 0 else {
                    throw MQTTProtocolError("Invalid PubAck fixed header data")
                }
                return .pubAck
                
            case .pubRec:
                guard packet.fixedHeaderData == 0 else {
                    throw MQTTProtocolError("Invalid PubRec fixed header data")
                }
                return .pubRec
                
            case .pubRel:
                guard packet.fixedHeaderData == Self.relFixedHeaderData else {
                    throw MQTTProtocolError("Invalid PubRel fixed header data")
                }
                return .pubRel
                
            case .pubComp:
                guard packet.fixedHeaderData == 0 else {
                    throw MQTTProtocolError("Invalid PubComp fixed header data")
                }
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
    // Wrapper to avoid heap allocations when added to NIOAny
    private class Data {
        let kind: Kind
        let packetId: UInt16
        let reasonCode: ReasonCode
        let reasonString: String?
        let userProperties: [MQTTUserProperty]
        
        init(
            kind: Kind,
            packetId: UInt16,
            reasonCode: ReasonCode,
            reasonString: String?,
            userProperties: [MQTTUserProperty]
        ) {
            self.kind = kind
            self.packetId = packetId
            self.reasonCode = reasonCode
            self.reasonString = reasonString
            self.userProperties = userProperties
        }
    }
    
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
        
        fileprivate init(_ code: MQTTAcknowledgementResponse.Error.Code?) {
            guard let code = code else {
                self = .success
                return
            }
            
            switch code {
            case .unspecifiedError: self = .unspecifiedError
                case .implementationSpecificError: self = .implementationSpecificError
            case .notAuthorized: self = .notAuthorized
                case .topicNameInvalid: self = .topicNameInvalid
            case .quotaExceeded: self = .quotaExceeded
            }
        }
        
        fileprivate init?(rawValue: UInt8, kind: Kind) {
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
        
        fileprivate var mqttReasonCode: MQTTReasonCode {
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
