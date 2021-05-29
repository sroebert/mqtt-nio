import NIO

extension MQTTPacket {
    struct Auth: MQTTPacketDuplexType {
        
        // MARK: - Vars
        
        var reasonCode: ReasonCode {
            return data.reasonCode
        }
        
        var reasonString: String? {
            return data.reasonString
        }
        
        var authenticationMethod: String? {
            return data.authenticationMethod
        }
        
        var authenticationData: ByteBuffer? {
            return data.authenticationData
        }
        
        private let data: Data
        
        // MARK: - Lifecycle
        
        init(
            reasonCode: ReasonCode,
            reasonString: String?,
            authenticationMethod: String?,
            authenticationData: ByteBuffer?
        ) {
            data = Data(
                reasonCode: reasonCode,
                reasonString: reasonString,
                authenticationMethod: authenticationMethod,
                authenticationData: authenticationData
            )
        }
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard version >= .version5 else {
                throw MQTTProtocolError(
                    "Received invalid auth packet in MQTT protocol version lower than 5"
                )
            }
            
            guard packet.fixedHeaderData == 0 else {
                throw MQTTProtocolError("Invalid Ack fixed header data")
            }
            
            guard let reasonCodeValue = packet.data.readInteger(as: UInt8.self) else {
                return Auth(
                    reasonCode: .success,
                    reasonString: nil,
                    authenticationMethod: nil,
                    authenticationData: nil
                )
            }
            
            guard let reasonCode = ReasonCode(rawValue: reasonCodeValue) else {
                throw MQTTProtocolError("Invalid auth reason code")
            }
            
            let properties = try MQTTProperties.parse(from: &packet.data, using: propertiesParser)
            
            return Auth(
                reasonCode: reasonCode,
                reasonString: properties.reasonString,
                authenticationMethod: properties.authenticationMethod,
                authenticationData: properties.authenticationData
            )
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            guard version >= .version5 else {
                throw MQTTProtocolError(
                    "Cannot send auth packet in MQTT protocol version lower than 5."
                )
            }
            
            guard
                reasonCode != .success ||
                authenticationMethod != nil ||
                authenticationData != nil
            else {
                return MQTTPacket(kind: .auth)
            }
            
            var buffer = Allocator.shared.buffer(capacity: 0)
            buffer.writeInteger(data.reasonCode.mqttReasonCode.rawValue)
            
            var properties = MQTTProperties()
            properties.authenticationMethod = data.authenticationMethod
            properties.authenticationData = data.authenticationData
            properties.reasonString = data.reasonString
            try properties.serialize(to: &buffer)
            
            return MQTTPacket(kind: .auth, data: buffer)
        }
        
        // MARK: - Utils
        
        @MQTTPropertiesParserBuilder
        private static var propertiesParser: MQTTPropertiesParser {
            \.$authenticationMethod
            \.$authenticationData
            \.$reasonString
        }
    }
}

extension MQTTPacket.Auth {
    // Wrapper to avoid heap allocations when added to NIOAny
    private class Data {
        let reasonCode: ReasonCode
        let reasonString: String?
        let authenticationMethod: String?
        let authenticationData: ByteBuffer?
        
        init(
            reasonCode: ReasonCode,
            reasonString: String?,
            authenticationMethod: String?,
            authenticationData: ByteBuffer?
        ) {
            self.reasonCode = reasonCode
            self.reasonString = reasonString
            self.authenticationMethod = authenticationMethod
            self.authenticationData = authenticationData
        }
    }
    
    enum ReasonCode {
        case success
        case continueAuthentication
        case reAuthenticate
        
        fileprivate init?(rawValue: UInt8) {
            guard let reasonCode = MQTTReasonCode(rawValue: rawValue) else {
                return nil
            }
            
            switch reasonCode {
            case .success: self = .success
            case .continueAuthentication: self = .continueAuthentication
            case .reAuthenticate: self = .reAuthenticate
            
            default:
                return nil
            }
        }
        
        fileprivate var mqttReasonCode: MQTTReasonCode {
            switch self {
            case .success: return .success
            case .continueAuthentication: return .continueAuthentication
            case .reAuthenticate: return .reAuthenticate
            }
        }
    }
}
