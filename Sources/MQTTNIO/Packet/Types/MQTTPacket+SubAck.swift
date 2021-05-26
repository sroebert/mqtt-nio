import NIO

extension MQTTPacket {
    struct SubAck: MQTTPacketInboundType {
        
        // MARK: - Vars
        
        var packetId: UInt16 {
            return data.packetId
        }
        
        var properties: MQTTProperties {
            return data.properties
        }
        
        var results: [MQTTSubscriptionResult] {
            return data.results
        }
        
        private var data: Data
        
        // MARK: - Init
        
        private init(
            packetId: UInt16,
            properties: MQTTProperties,
            results: [MQTTSubscriptionResult]
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
            guard let packetId = packet.data.readInteger(as: UInt16.self) else {
                throw MQTTProtocolError("Missing packet identifier")
            }
            
            let properties: MQTTProperties
            if version >= .version5 {
                properties = try .parse(from: &packet.data, using: propertiesParser)
            } else {
                properties = MQTTProperties()
            }
            
            var results: [MQTTSubscriptionResult] = []
            while let reasonCodeValue = packet.data.readInteger(as: UInt8.self) {
                guard let parsedReasonCode = ReasonCode(rawValue: reasonCodeValue) else {
                    throw MQTTProtocolError("Invalid subscription acknowledgement reason code")
                }
                
                results.append(parsedReasonCode.result)
            }
            
            return SubAck(
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

extension MQTTPacket.SubAck {
    // Wrapper to avoid heap allocations when added to NIOAny
    private class Data {
        let packetId: UInt16
        let properties: MQTTProperties
        let results: [MQTTSubscriptionResult]
        
        init(
            packetId: UInt16,
            properties: MQTTProperties,
            results: [MQTTSubscriptionResult]
        ) {
            self.packetId = packetId
            self.properties = properties
            self.results = results
        }
    }
    
    private enum ReasonCode {
        case grantedQoS0
        case grantedQoS1
        case grantedQoS2
        case unspecifiedError
        case implementationSpecificError
        case notAuthorized
        case topicFilterInvalid
        case packetIdentifierInUse
        case quotaExceeded
        case sharedSubscriptionsNotSupported
        case subscriptionIdentifiersNotSupported
        case wildcardSubscriptionsNotSupported
        
        init?(rawValue: UInt8) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch reasonCode {
            case .success: self = .grantedQoS0
            case .grantedQoS1: self = .grantedQoS1
            case .grantedQoS2: self = .grantedQoS2
            case .unspecifiedError: self = .unspecifiedError
            case .implementationSpecificError: self = .implementationSpecificError
            case .notAuthorized: self = .notAuthorized
            case .topicFilterInvalid: self = .topicFilterInvalid
            case .packetIdentifierInUse: self = .packetIdentifierInUse
            case .quotaExceeded: self = .quotaExceeded
            case .sharedSubscriptionsNotSupported: self = .sharedSubscriptionsNotSupported
            case .subscriptionIdentifiersNotSupported: self = .subscriptionIdentifiersNotSupported
            case .wildcardSubscriptionsNotSupported: self = .wildcardSubscriptionsNotSupported
                
            default:
                return nil
            }
        }
        
        var result: MQTTSubscriptionResult {
            switch self {
            case .grantedQoS0:
                return .success(.atMostOnce)
            case .grantedQoS1:
                return .success(.atLeastOnce)
            case .grantedQoS2:
                return .success(.exactlyOnce)
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
            case .quotaExceeded:
                return .failure(.quotaExceeded)
            case .sharedSubscriptionsNotSupported:
                return .failure(.sharedSubscriptionsNotSupported)
            case .subscriptionIdentifiersNotSupported:
                return .failure(.subscriptionIdentifiersNotSupported)
            case .wildcardSubscriptionsNotSupported:
                return .failure(.wildcardSubscriptionsNotSupported)
            }
        }
    }
}
