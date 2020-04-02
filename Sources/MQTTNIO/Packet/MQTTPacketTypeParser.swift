import NIO
import Logging

final class MQTTPacketTypeParser: ChannelInboundHandler {
    typealias InboundIn = MQTTPacket
    typealias InboundOut = MQTTPacket.Inbound

    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        do {
            let inbound = try parse(packet)
            context.fireChannelRead(wrapInboundOut(inbound))
        } catch {
            logger.notice("Could not parse inbound packet", metadata: [
                "inboundType": "\(type(of: packet))",
                "error": "\(error)"
            ])
            
            context.fireErrorCaught(error)
        }
    }
    
    private func parse(_ packet: MQTTPacket) throws -> MQTTPacket.Inbound {
        return try MQTTPacket.Inbound(packet: packet)
    }
}
