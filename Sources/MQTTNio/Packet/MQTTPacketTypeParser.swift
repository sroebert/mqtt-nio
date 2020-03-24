import NIO
import Logging

final class MQTTPacketTypeParser: ChannelInboundHandler {
    typealias InboundIn = MQTTPacket
    typealias InboundOut = MQTTPacket.Inbound

    let logger: Logger?
    
    init(logger: Logger? = nil) {
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        do {
            let inbound = try parse(packet)
            context.fireChannelRead(wrapInboundOut(inbound))
        } catch {
            context.fireErrorCaught(error)
        }
    }
    
    private func parse(_ packet: MQTTPacket) throws -> MQTTPacket.Inbound {
        switch packet.kind {
        case .connAck:
            return try .connAck(.parse(from: packet))
            
        default:
            return .unknown(packet)
        }
    }
}
