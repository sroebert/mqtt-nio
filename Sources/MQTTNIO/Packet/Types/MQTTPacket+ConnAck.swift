import NIO

extension MQTTPacket {
    struct ConnAck: MQTTPacketInboundType {
        var reasonCode: ReasonCode
        var isSessionPresent: Bool
        var properties: MQTTProperties
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard
                let acknowledgeFlags = packet.data.readInteger(as: UInt8.self),
                let reasonCodeValue = packet.data.readInteger(as: UInt8.self)
            else {
                throw MQTTProtocolError("Invalid ConnAck structure")
            }
            
            let reasonCode: ReasonCode
            let properties: MQTTProperties
            
            switch version {
            case .version3_1_1:
                guard let reasonCode311 = ReasonCode311(rawValue: reasonCodeValue) else {
                    throw MQTTProtocolError("Invalid ConnAck reason code")
                }
                reasonCode = .version311(reasonCode311)
                properties = MQTTProperties()
                
            case .version5:
                guard let reasonCode5 = ReasonCode5(rawValue: reasonCodeValue) else {
                    throw MQTTProtocolError("Invalid ConnAck reason code")
                }
                reasonCode = .version5(reasonCode5)
                properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
            }
            
            return ConnAck(
                reasonCode: reasonCode,
                isSessionPresent: (acknowledgeFlags & 0x01) != 0,
                properties: properties
            )
        }
        
        @MQTTPropertiesParserBuilder
        private static var propertiesParser: MQTTPropertiesParser {
            \.$sessionExpiry
            \.$receiveMaximum
            \.$maximumQoS
            \.$retainAvailable
            \.$maximumPacketSize
            \.$assignedClientIdentifier
            \.$topicAliasMaximum
            \.$reasonString
            \.$userProperties
            \.$wildcardSubscriptionAvailable
            \.$subscriptionIdentifierAvailable
            \.$sharedSubscriptionAvailable
            \.$serverKeepAlive
            \.$responseInformation
            \.$serverReference
            \.$authenticationMethod
            \.$authenticationData
        }
    }
}

extension MQTTPacket.ConnAck {
    enum ReasonCode {
        case version311(ReasonCode311)
        case version5(ReasonCode5)
        
        var isSuccess: Bool {
            switch self {
            case .version311(let reasonCode):
                return reasonCode.isAccepted
                
            case .version5(let reasonCode):
                return reasonCode.isSuccess
            }
        }
    }
    
    enum ReasonCode311: UInt8 {
        case accepted                       = 0x00
        case unacceptableProtocolVersion    = 0x01
        case identifierRejected             = 0x02
        case serverUnavailable              = 0x03
        case badUsernameOrPassword          = 0x04
        case notAuthorized                  = 0x05
        
        var isAccepted: Bool {
            if case .accepted = self {
                return true
            }
            return false
        }
    }
    
    enum ReasonCode5 {
        case success
        case unspecifiedError
        case malformedPacket
        case protocolError
        case implementationSpecificError
        case unsupportedProtocolVersion
        case clientIdentifierNotValid
        case badUsernameOrPassword
        case notAuthorized
        case serverUnavailable
        case serverBusy
        case banned
        case badAuthenticationMethod
        case topicNameInvalid
        case packetTooLarge
        case quotaExceeded
        case payloadFormatInvalid
        case retainNotSupported
        case qosNotSupported
        case useAnotherServer
        case serverMoved
        case connectionRateExceeded
        
        init?(rawValue: UInt8) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch reasonCode {
            case .success: self = .success
            case .unspecifiedError: self = .unspecifiedError
            case .malformedPacket: self = .malformedPacket
            case .protocolError: self = .protocolError
            case .implementationSpecificError: self = .implementationSpecificError
            case .unsupportedProtocolVersion: self = .unsupportedProtocolVersion
            case .clientIdentifierNotValid: self = .clientIdentifierNotValid
            case .badUsernameOrPassword: self = .badUsernameOrPassword
            case .notAuthorized: self = .notAuthorized
            case .serverUnavailable: self = .serverUnavailable
            case .serverBusy: self = .serverBusy
            case .banned: self = .banned
            case .badAuthenticationMethod: self = .badAuthenticationMethod
            case .topicNameInvalid: self = .topicNameInvalid
            case .packetTooLarge: self = .packetTooLarge
            case .quotaExceeded: self = .quotaExceeded
            case .payloadFormatInvalid: self = .payloadFormatInvalid
            case .retainNotSupported: self = .retainNotSupported
            case .qosNotSupported: self = .qosNotSupported
            case .useAnotherServer: self = .useAnotherServer
            case .serverMoved: self = .serverMoved
            case .connectionRateExceeded: self = .connectionRateExceeded
                
            default:
                return nil
            }
        }
        
        var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }
    }
}
