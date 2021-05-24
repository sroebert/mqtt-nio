import NIO

extension MQTTPacket {
    struct Auth: MQTTPacketDuplexType {
        
        // MARK: - MQTTPacketDuplexType
        
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            return Auth()
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            return MQTTPacket(kind: .auth)
        }
    }
}
