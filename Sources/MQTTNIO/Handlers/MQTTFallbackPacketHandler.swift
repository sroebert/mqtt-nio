import NIO
import NIOConcurrencyHelpers
import Logging

final class MQTTFallbackPacketHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = Never
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let version: MQTTProtocolVersion
    let logger: Logger
    
    // MARK: - Init
    
    init(
        version: MQTTProtocolVersion,
        logger: Logger
    ) {
        self.version = version
        self.logger = logger
    }
    
    // MARK: - ChannelDuplexHandler
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        guard version > .version5 else {
            // Versions lower than 5 do not support reasons
            logUnprocessedPacket(packet)
            return
        }
        
        switch packet {
        case .acknowledgement(let acknowledgement):
            respond(to: acknowledgement, context: context)
            
        default:
            logUnprocessedPacket(packet)
        }
    }
    
    // MARK: - Log
    
    private func logUnprocessedPacket(_ packet: MQTTPacket.Inbound) {
        logger.debug("Received unprocessed packet", metadata: [
            "kind": "\(packet)"
        ])
    }
    
    // MARK: - Respond
    
    private func respond(to acknowledgement: MQTTPacket.Acknowledgement, context: ChannelHandlerContext) {
        switch acknowledgement.kind {
        case .pubAck, .pubComp:
            // It can happen that we receive more than one .pubAck or .pubComp, simply ignore
            break
            
        case .pubRec, .pubRel:
            // If we receive an unhandled pubRel or pubRec, let the broker know it is unknown.
            logger.debug("Received invalid acknowledgement for packet identifier", metadata: [
                "packetId": .stringConvertible(acknowledgement.packetId),
            ])
            
            let packet = MQTTPacket.Acknowledgement(
                kind: acknowledgement.kind == .pubRec ? .pubRel : .pubComp,
                packetId: acknowledgement.packetId,
                reasonCode: .packetIdentifierNotFound
            )
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
        }
    }
}
