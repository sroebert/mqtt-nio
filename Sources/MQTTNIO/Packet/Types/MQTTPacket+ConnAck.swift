import NIO

extension MQTTPacket {
    struct ConnAck: MQTTPacketInboundType {
        var returnCode: ReturnCode
        var isSessionPresent: Bool
        var properties: MQTTProperties
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard
                let acknowledgeFlags = packet.data.readInteger(as: UInt8.self),
                let returnCodeValue = packet.data.readInteger(as: UInt8.self)
            else {
                throw MQTTProtocolError.parsingError("Invalid ConnAck structure")
            }
            
            let returnCode: ReturnCode
            let properties: MQTTProperties
            
            switch version {
            case .version3_1_1:
                guard let returnCode311 = ReturnCode311(rawValue: returnCodeValue) else {
                    throw MQTTProtocolError.parsingError("Invalid ConnAck reason code")
                }
                returnCode = .version311(returnCode311)
                properties = MQTTProperties()
                
            case .version5:
                guard let returnCode5 = ReturnCode5(rawValue: returnCodeValue) else {
                    throw MQTTProtocolError.parsingError("Invalid ConnAck return code")
                }
                returnCode = .version5(returnCode5)
                properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
            }
            
            return ConnAck(
                returnCode: returnCode,
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
    enum ReturnCode {
        case version311(ReturnCode311)
        case version5(ReturnCode5)
        
        var isSuccess: Bool {
            switch self {
            case .version311(let returnCode):
                return returnCode.isAccepted
                
            case .version5(let returnCode):
                return returnCode.isSuccess
            }
        }
    }
    
    enum ReturnCode311: UInt8 {
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
    
    enum ReturnCode5: UInt8 {
        case success                        = 0x00
        case unspecifiedError               = 0x80
        case malformedPacket                = 0x81
        case protocolError                  = 0x82
        case implementationSpecificError    = 0x83
        case unsupportedProtocolVersion     = 0x84
        case clientIdentifierNotValid       = 0x85
        case badUsernameOrPassword          = 0x86
        case notAuthorized                  = 0x87
        case serverUnavailable              = 0x88
        case serverBusy                     = 0x89
        case banned                         = 0x8A
        case badAuthenticationMethod        = 0x8C
        case topicNameInvalid               = 0x90
        case packetTooLarge                 = 0x95
        case quotaExceeded                  = 0x97
        case payloadFormatInvalid           = 0x99
        case retainNotSupported             = 0x9A
        case qosNotSupported                = 0x9B
        case useAnotherServer               = 0x9C
        case serverMoved                    = 0x9D
        case connectionRateExceeded         = 0x9F
        
        var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }
    }
}
