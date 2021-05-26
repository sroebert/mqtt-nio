import NIO

extension MQTTPacket {
    struct Auth: MQTTPacketDuplexType {
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard version >= .version5 else {
                throw MQTTProtocolError("Received invalid auth packet")
            }
            
            return Auth()
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            return MQTTPacket(kind: .auth)
        }
    }
}
