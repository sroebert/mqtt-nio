import NIO

extension MQTTPacket {
    struct ConnAck: MQTTPacketInboundType {
        var isSessionPresent: Bool
        var returnCode: ReturnCode
        
        static func parse(from packet: inout MQTTPacket) throws -> Self {
            guard
                let acknowledgeFlags = packet.data.readInteger(as: UInt8.self),
                let returnCodeValue = packet.data.readInteger(as: UInt8.self)
            else {
                throw MQTTProtocolError.parsingError("Invalid ConnAck structure")
            }
            
            guard let returnCode = ReturnCode(rawValue: returnCodeValue) else {
                throw MQTTProtocolError.parsingError("Invalid ConnAck return code")
            }
            
            return ConnAck(
                isSessionPresent: (acknowledgeFlags & 0x01) != 0,
                returnCode: returnCode
            )
        }
    }
}

extension MQTTPacket.ConnAck {
    enum ReturnCode: UInt8 {
        case accepted = 0
        case unacceptableProtocolVersion = 1
        case identifierRejected = 2
        case serverUnavailable = 3
        case badUsernameOrPassword = 4
        case notAuthorized = 5
    }
}
