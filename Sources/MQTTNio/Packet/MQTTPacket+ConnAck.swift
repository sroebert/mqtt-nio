import NIO

extension MQTTPacket {
    struct ConnAck: MQTTPacketType {
        static var identifier: MQTTPacket.Identifier {
            return .connAck
        }
        
        var isSessionPresent: Bool
        var returnCode: ReturnCode
        
        static func parse(fixedHeaderData: UInt8, buffer: inout ByteBuffer) throws -> Self {
            guard
                let acknowledgeFlags = buffer.readInteger(as: UInt8.self),
                let returnCodeValue = buffer.readInteger(as: UInt8.self)
            else {
                throw MQTTConnectionError.protocol("Could not parse ConnAck")
            }
            
            return ConnAck(
                isSessionPresent: (acknowledgeFlags & 0x01) != 0,
                returnCode: .init(integerLiteral: returnCodeValue)
            )
        }
    }
}

extension MQTTPacket.ConnAck {
    struct ReturnCode: ExpressibleByIntegerLiteral, Equatable {
        
        static let accepted: ReturnCode                      = 0
        
        static let unacceptableProtocolVersion: ReturnCode   = 1
        static let identifierRejected: ReturnCode            = 2
        static let serverUnavailable: ReturnCode             = 3
        static let badUsernameOrPassword: ReturnCode         = 4
        static let notAuthorized: ReturnCode                 = 5
        
        let value: UInt8
        
        init(integerLiteral value: UInt8) {
            self.value = value
        }
    }
}
