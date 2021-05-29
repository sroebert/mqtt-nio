import NIO

extension MQTTPacket {
    struct UnsubAck: MQTTPacketInboundType {
        
        // MARK: - Vars
        
        var packetId: UInt16 {
            return data.packetId
        }
        
        var properties: MQTTProperties {
            return data.properties
        }
        
        var results: [MQTTUnsubscribeResult]? {
            return data.results
        }
        
        private var data: Data
        
        // MARK: - Init
        
        private init(
            packetId: UInt16,
            properties: MQTTProperties,
            results: [MQTTUnsubscribeResult]?
        ) {
            data = Data(
                packetId: packetId,
                properties: properties,
                results: results
            )
        }
        
        // MARK: - MQTTPacketOutboundType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard packet.fixedHeaderData == 0 else {
                throw MQTTProtocolError("Invalid UnsubAck fixed header data")
            }
            
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTProtocolError("Missing packet identifier")
            }
            
            guard version >= .version5 else {
                return UnsubAck(
                    packetId: packetId,
                    properties: MQTTProperties(),
                    results: nil
                )
            }
            
            let properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
            
            var results: [MQTTUnsubscribeResult] = []
            while let reasonCodeValue = packet.data.readInteger(as: UInt8.self) {
                guard let parsedReasonCode = ReasonCode(rawValue: reasonCodeValue) else {
                    throw MQTTProtocolError("Invalid unsubscripe acknowledgement reason code")
                }
                
                results.append(parsedReasonCode.result)
            }
            
            return UnsubAck(
                packetId: packetId,
                properties: properties,
                results: results
            )
        }
        
        // MARK: - Utils
        
        @MQTTPropertiesParserBuilder
        private static var propertiesParser: MQTTPropertiesParser {
            \.$reasonString
            \.$userProperties
        }
    }
}

extension MQTTPacket.UnsubAck {
    // Wrapper to avoid heap allocations when added to NIOAny
    private class Data {
        let packetId: UInt16
        let properties: MQTTProperties
        let results: [MQTTUnsubscribeResult]?
        
        init(
            packetId: UInt16,
            properties: MQTTProperties,
            results: [MQTTUnsubscribeResult]?
        ) {
            self.packetId = packetId
            self.properties = properties
            self.results = results
        }
    }

    private enum ReasonCode {
        case success
        case noSubscriptionExisted
        case unspecifiedError
        case implementationSpecificError
        case notAuthorized
        case topicFilterInvalid
        case packetIdentifierInUse
        
        init?(rawValue: UInt8) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch reasonCode {
            case .success: self = .success
            case .noSubscriptionExisted: self = .noSubscriptionExisted
            case .unspecifiedError: self = .unspecifiedError
            case .implementationSpecificError: self = .implementationSpecificError
            case .notAuthorized: self = .notAuthorized
            case .topicFilterInvalid: self = .topicFilterInvalid
            case .packetIdentifierInUse: self = .packetIdentifierInUse
                
            default:
                return nil
            }
        }
        
        var result: MQTTUnsubscribeResult {
            switch self {
            case .success:
                return .success
            case .noSubscriptionExisted:
                return .success
            case .unspecifiedError:
                return .failure(.unspecifiedError)
            case .implementationSpecificError:
                return .failure(.implementationSpecificError)
            case .notAuthorized:
                return .failure(.notAuthorized)
            case .topicFilterInvalid:
                return .failure(.topicFilterInvalid)
            case .packetIdentifierInUse:
                return .failure(.packetIdentifierInUse)
            }
        }
    }
}
