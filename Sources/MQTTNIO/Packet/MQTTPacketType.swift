import NIO

protocol MQTTPacketInboundType {
    static func parse(
        from packet: inout MQTTPacket,
        version: MQTTProtocolVersion
    ) throws -> Self
}

protocol MQTTPacketOutboundType {
    func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket
}

typealias MQTTPacketDuplexType = MQTTPacketInboundType & MQTTPacketOutboundType

extension MQTTPacket {
    enum Inbound {
        case connAck(ConnAck)
        case publish(Publish)
        case acknowledgement(Acknowledgement)
        case pingResp(PingResp)
        case subAck(SubAck)
        case unsubAck(UnsubAck)
        case auth(Auth)
        case unknown(MQTTPacket)
        
        init(packet: MQTTPacket, version: MQTTProtocolVersion) throws {
            switch packet.kind {
            case .connAck:
                self = try .connAck(.parse(from: packet, version: version))
                
            case .publish:
                self = try .publish(.parse(from: packet, version: version))
                
            case .pubAck, .pubRec, .pubRel, .pubComp:
                self = try .acknowledgement(.parse(from: packet, version: version))
                
            case .pingResp:
                self = try .pingResp(.parse(from: packet, version: version))
                
            case .subAck:
                self = try .subAck(.parse(from: packet, version: version))
                
            case .unsubAck:
                self = try .unsubAck(.parse(from: packet, version: version))
                
            case .auth:
                self = try .auth(.parse(from: packet, version: version))
                
            default:
                self = .unknown(packet)
            }
        }
    }
    
    typealias Outbound = MQTTPacketOutboundType
}

extension MQTTPacketInboundType {
    static func parse(
        from packet: MQTTPacket,
        version: MQTTProtocolVersion
    ) throws -> Self {
        var packet = packet
        return try parse(from: &packet, version: version)
    }
}
