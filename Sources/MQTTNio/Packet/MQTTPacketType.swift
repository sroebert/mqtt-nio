import NIO

protocol MQTTPacketInboundType {
    static func parse(from packet: inout MQTTPacket) throws -> Self
}

protocol MQTTPacketOutboundType {
    func serialize(using idProvider: MQTTPacketOutboundIDProvider) throws -> MQTTPacket
}

typealias MQTTPacketDuplexType = MQTTPacketInboundType & MQTTPacketOutboundType

protocol MQTTPacketOutboundIDProvider {
    func getNextPacketId() -> UInt16
}

extension MQTTPacket {
    enum Inbound {
        case connAck(ConnAck)
        case unknown(MQTTPacket)
    }
    
    typealias Outbound = MQTTPacketOutboundType
}

extension MQTTPacketInboundType {
    static func parse(from packet: MQTTPacket) throws -> Self {
        var packet = packet
        return try parse(from: &packet)
    }
}
