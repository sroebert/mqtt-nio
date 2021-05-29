import NIO

extension MQTTPacket {
    struct PingReq: MQTTPacketOutboundType {
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            return MQTTPacket(kind: .pingReq)
        }
    }
    
    struct PingResp: MQTTPacketInboundType {
        static func parse(
            from packet: inout MQTTPacket,
            version: MQTTProtocolVersion
        ) throws -> Self {
            guard packet.fixedHeaderData == 0 else {
                throw MQTTProtocolError("Invalid PingResp fixed header data")
            }
            
            return MQTTPacket.PingResp()
        }
        
        private init() {}
    }
}
