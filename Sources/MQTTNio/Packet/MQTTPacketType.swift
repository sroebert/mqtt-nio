import NIO

protocol MQTTPacketInboundType {
    static func parse(from packet: inout MQTTPacket) throws -> Self
}

protocol MQTTPacketOutboundType {
    func serialize() throws -> MQTTPacket
}

typealias MQTTPacketDuplexType = MQTTPacketInboundType & MQTTPacketOutboundType

extension MQTTPacket {
    enum Inbound {
        case connAck(ConnAck)
        case publish(Publish)
        case acknowledgement(Acknowledgement)
        case pingResp(PingResp)
        case unknown(MQTTPacket)
        
        init(packet: MQTTPacket) throws {
            switch packet.kind {
            case .connAck:
                self = try .connAck(.parse(from: packet))
                
            case .publish:
                self = try .publish(.parse(from: packet))
                
            case .pubAck, .pubRec, .pubRel, .pubComp:
                self = try .acknowledgement(.parse(from: packet))
                
            case .pingResp:
                self = try .pingResp(.parse(from: packet))
                
            default:
                self = .unknown(packet)
            }
        }
    }
    
    typealias Outbound = MQTTPacketOutboundType
}

extension MQTTPacketInboundType {
    static func parse(from packet: MQTTPacket) throws -> Self {
        var packet = packet
        return try parse(from: &packet)
    }
}
