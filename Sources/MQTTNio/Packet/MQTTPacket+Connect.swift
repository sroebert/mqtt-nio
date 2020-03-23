import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let config: MQTTConnection.ConnectConfig
    
    // MARK: - Init
    
    init(config: MQTTConnection.ConnectConfig) {
        self.config = config
    }
    
    // MARK: - MQTTRequest
    
    func start() throws -> MQTTPacket {
        return try MQTTPacket.Connect(config: config).message()
    }
    
    func shouldProcess(_ packet: MQTTPacket) throws -> Bool {
        return true
    }
    
    func process(_ packet: MQTTPacket, appendResponse: (MQTTPacket) -> Void) throws -> MQTTRequestProcessResult {
        guard packet.identifier == .connAck else {
            let error = MQTTConnectionError.protocol("Received invalid packet after sending connect: \(packet.identifier)")
            return .failure(error)
        }
        
        let connAck = try MQTTPacket.ConnAck(packet)
        switch connAck.returnCode {
        case .accepted:
            return .success
            
        case .unacceptableProtocolVersion:
            return .failure(MQTTServerError.unacceptableProtocolVersion)
        case .identifierRejected:
            return .failure(MQTTServerError.identifierRejected)
        case .serverUnavailable:
            return .failure(MQTTServerError.serverUnavailable)
        case .badUsernameOrPassword:
            return .failure(MQTTServerError.badUsernameOrPassword)
        case .notAuthorized:
            return .failure(MQTTServerError.notAuthorized)
            
        default:
            return .failure(MQTTServerError.unknown)
        }
    }
    
    func log(to logger: Logger) {
        logger.debug("Sending connect packet to server")
    }
}

extension MQTTPacket {
    fileprivate struct Connect: MQTTPacketType {
        static var identifier: MQTTPacket.Identifier {
            return .connect
        }
        
        private static let protocolName = "MQTT"
        private static let protocolLevel: UInt8 = 0x04 // 3.1.1
        
        var config: MQTTConnection.ConnectConfig
        
        func serialize(fixedHeaderData: inout UInt8, buffer: inout ByteBuffer) throws {
            
            // Variable header
            try buffer.writeMQTTString(Self.protocolName, "Protocol name")
            buffer.writeInteger(Self.protocolLevel)
            
            // leave room for flags
            let flagsIndex = buffer.writerIndex
            buffer.moveWriterIndex(forwardBy: 1)
            
            buffer.writeInteger(config.keepAliveInterval)
            
            // Payload
            let flags = try serializePayload(into: &buffer)
            buffer.setInteger(flags.rawValue, at: flagsIndex)
        }
        
        private func serializePayload(into buffer: inout ByteBuffer) throws -> Flags {
            var flags: Flags = []
            
            if config.cleanSession {
                flags.insert(.cleanSession)
            }
            
            try buffer.writeMQTTString(config.clientId, "Client Identifier")
            
            if let lastWillMessage = config.lastWillMessage {
                flags.insert(.containsLastWill)
                try buffer.writeMQTTString(lastWillMessage.topic, "Topic")
                
                if var payload = lastWillMessage.payload {
                    try buffer.writeMQTTPayload(&payload, "Last Will Payload")
                } else {
                    buffer.writeInteger(UInt16(0))
                }
                
                switch lastWillMessage.qos {
                case .atMostOnce:
                    break
                case .atLeastOnce:
                    flags.insert(.lastWillQoS1)
                case .exactlyOnce:
                    flags.insert(.lastWillQoS2)
                }
                
                if lastWillMessage.retain {
                    flags.insert(.lastWillRetain)
                }
            }
            
            if let credentials = config.credentials {
                flags.insert(.containsUsername)
                try buffer.writeMQTTString(credentials.username, "Username")
                
                if var password = credentials.password {
                    flags.insert(.containsPassword)
                    try buffer.writeMQTTPayload(&password, "Password")
                }
            }
            
            return flags
        }
    }
}

extension MQTTPacket.Connect {
    fileprivate struct Flags: OptionSet {
        let rawValue: UInt8
        
        static let cleanSession = Flags(rawValue: 1 << 1)
        static let containsLastWill = Flags(rawValue: 1 << 2)
        static let lastWillQoS1 = Flags(rawValue: 1 << 3)
        static let lastWillQoS2 = Flags(rawValue: 1 << 4)
        static let lastWillRetain = Flags(rawValue: 1 << 5)
        static let containsPassword = Flags(rawValue: 1 << 6)
        static let containsUsername = Flags(rawValue: 1 << 7)
        
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}
