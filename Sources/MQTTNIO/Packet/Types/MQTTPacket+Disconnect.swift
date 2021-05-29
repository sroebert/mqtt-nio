import NIO

extension MQTTPacket {
    struct Disconnect: MQTTPacketDuplexType {
        
        // MARK: - Vars
        
        var reasonCode: ReasonCode {
            return data.reasonCode
        }
        
        var properties: MQTTProperties {
            return data.properties
        }
        
        private let data: Data
        
        // MARK: - Init
        
        init(
            reasonCode: ReasonCode,
            reasonString: String? = nil,
            sessionExpiry: MQTTConfiguration.SessionExpiry?,
            userProperties: [MQTTUserProperty]
        ) {
            var properties = MQTTProperties()
            properties.reasonString = reasonString
            properties.sessionExpiry = sessionExpiry
            properties.userProperties = userProperties
            
            self.init(
                reasonCode: reasonCode,
                properties: properties
            )
        }
        
        private init(
            reasonCode: ReasonCode,
            properties: MQTTProperties
        ) {
            data = Data(
                reasonCode: reasonCode,
                properties: properties
            )
        }
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard version >= .version5 else {
                throw MQTTProtocolError(
                    code: .protocolError,
                    "Received invalid disconnect packet"
                )
            }
            
            guard packet.fixedHeaderData == 0 else {
                throw MQTTProtocolError("Invalid Disconnect fixed header data")
            }
            
            guard let reasonCodeValue = packet.data.readInteger(as: UInt8.self) else {
                throw MQTTProtocolError("Invalid disconnect packet structure")
            }
            
            guard
                let reasonCode = ReasonCode(rawValue: reasonCodeValue),
                reasonCode != .disconnectWithWillMessage
            else {
                throw MQTTProtocolError("Invalid disconnect reason code")
            }
            
            let properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
            
            return Disconnect(
                reasonCode: reasonCode,
                properties: properties
            )
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            guard version >= .version5 else {
                return MQTTPacket(kind: .disconnect)
            }
            
            var buffer = Allocator.shared.buffer(capacity: 0)
            buffer.writeInteger(reasonCode.mqttReasonCode.rawValue)
            try properties.serialize(to: &buffer)
            
            return MQTTPacket(
                kind: .disconnect,
                data: buffer
            )
        }
        
        // MARK: - Utils
        
        @MQTTPropertiesParserBuilder
        private static var propertiesParser: MQTTPropertiesParser {
            \.$reasonString
            \.$userProperties
            \.$serverReference
        }
    }
}

extension MQTTPacket.Disconnect {
    // Wrapper to avoid heap allocations when added to NIOAny
    fileprivate class Data {
        let reasonCode: ReasonCode
        let properties: MQTTProperties
        
        init(
            reasonCode: ReasonCode,
            properties: MQTTProperties
        ) {
            self.reasonCode = reasonCode
            self.properties = properties
        }
    }
    
    enum ReasonCode {
        case normalDisconnection
        case disconnectWithWillMessage
        case unspecifiedError
        case malformedPacket
        case protocolError
        case implementationSpecificError
        case notAuthorized
        case serverBusy
        case serverShuttingDown
        case keepAliveTimeout
        case sessionTakenOver
        case topicFilterInvalid
        case topicNameInvalid
        case receiveMaximumExceeded
        case topicAliasInvalid
        case packetTooLarge
        case messageRateTooHigh
        case quotaExceeded
        case administrativeAction
        case payloadFormatInvalid
        case retainNotSupported
        case qosNotSupported
        case useAnotherServer
        case serverMoved
        case sharedSubscriptionsNotSupported
        case connectionRateExceeded
        case maximumConnectTime
        case subscriptionIdentifiersNotSupported
        case wildcardSubscriptionsNotSupported
        
        fileprivate init?(rawValue: UInt8) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch reasonCode {
            case .success: self = .normalDisconnection
            case .disconnectWithWillMessage: self = .disconnectWithWillMessage
            case .unspecifiedError: self = .unspecifiedError
            case .malformedPacket: self = .malformedPacket
            case .protocolError: self = .protocolError
            case .implementationSpecificError: self = .implementationSpecificError
            case .notAuthorized: self = .notAuthorized
            case .serverBusy: self = .serverBusy
            case .serverShuttingDown: self = .serverShuttingDown
            case .keepAliveTimeout: self = .keepAliveTimeout
            case .sessionTakenOver: self = .sessionTakenOver
            case .topicFilterInvalid: self = .topicFilterInvalid
            case .topicNameInvalid: self = .topicNameInvalid
            case .receiveMaximumExceeded: self = .receiveMaximumExceeded
            case .topicAliasInvalid: self = .topicAliasInvalid
            case .packetTooLarge: self = .packetTooLarge
            case .messageRateTooHigh: self = .messageRateTooHigh
            case .quotaExceeded: self = .quotaExceeded
            case .administrativeAction: self = .administrativeAction
            case .payloadFormatInvalid: self = .payloadFormatInvalid
            case .retainNotSupported: self = .retainNotSupported
            case .qosNotSupported: self = .qosNotSupported
            case .useAnotherServer: self = .useAnotherServer
            case .serverMoved: self = .serverMoved
            case .sharedSubscriptionsNotSupported: self = .sharedSubscriptionsNotSupported
            case .connectionRateExceeded: self = .connectionRateExceeded
            case .maximumConnectTime: self = .maximumConnectTime
            case .subscriptionIdentifiersNotSupported: self = .subscriptionIdentifiersNotSupported
            case .wildcardSubscriptionsNotSupported: self = .wildcardSubscriptionsNotSupported
            
            default:
                return nil
            }
        }
        
        fileprivate var mqttReasonCode: MQTTReasonCode {
            switch self {
            case .normalDisconnection: return .success
            case .disconnectWithWillMessage: return .disconnectWithWillMessage
            case .unspecifiedError: return .unspecifiedError
            case .malformedPacket: return .malformedPacket
            case .protocolError: return .protocolError
            case .implementationSpecificError: return .implementationSpecificError
            case .notAuthorized: return .notAuthorized
            case .serverBusy: return .serverBusy
            case .serverShuttingDown: return .serverShuttingDown
            case .keepAliveTimeout: return .keepAliveTimeout
            case .sessionTakenOver: return .sessionTakenOver
            case .topicFilterInvalid: return .topicFilterInvalid
            case .topicNameInvalid: return .topicNameInvalid
            case .receiveMaximumExceeded: return .receiveMaximumExceeded
            case .topicAliasInvalid: return .topicAliasInvalid
            case .packetTooLarge: return .packetTooLarge
            case .messageRateTooHigh: return .messageRateTooHigh
            case .quotaExceeded: return .quotaExceeded
            case .administrativeAction: return .administrativeAction
            case .payloadFormatInvalid: return .payloadFormatInvalid
            case .retainNotSupported: return .retainNotSupported
            case .qosNotSupported: return .qosNotSupported
            case .useAnotherServer: return .useAnotherServer
            case .serverMoved: return .serverMoved
            case .sharedSubscriptionsNotSupported: return .sharedSubscriptionsNotSupported
            case .connectionRateExceeded: return .connectionRateExceeded
            case .maximumConnectTime: return .maximumConnectTime
            case .subscriptionIdentifiersNotSupported: return .subscriptionIdentifiersNotSupported
            case .wildcardSubscriptionsNotSupported: return .wildcardSubscriptionsNotSupported
            }
        }
    }
}
