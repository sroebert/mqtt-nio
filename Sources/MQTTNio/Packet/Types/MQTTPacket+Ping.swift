import NIO

extension MQTTPacket {
    struct PingReq: MQTTPacketOutboundType {
        func serialize() throws -> MQTTPacket {
            return MQTTPacket(kind: .pingReq)
        }
    }
    
    struct PingResp: MQTTPacketInboundType {
        static func parse(from packet: inout MQTTPacket) throws -> MQTTPacket.PingResp {
            return MQTTPacket.PingResp()
        }
    }
}
