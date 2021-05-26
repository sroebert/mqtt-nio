import NIO
import Logging

final class MQTTPacketTypeSerializer: ChannelOutboundHandler {
    
    // MARK: - Vars
    
    let version: MQTTProtocolVersion
    let logger: Logger
    
    // MARK: - Init
    
    init(version: MQTTProtocolVersion, logger: Logger) {
        self.version = version
        self.logger = logger
    }
    
    // MARK: - ChannelOutboundHandler
    
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let outbound = unwrapOutboundIn(data)
        do {
            let packet = try outbound.serialize(version: version)
            context.write(wrapOutboundOut(packet), promise: promise)
        } catch {
            logger.notice("Could not serialize outbound packet", metadata: [
                "outboundType": "\(type(of: outbound))",
                "error": "\(error)"
            ])
            
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case is MQTTConnectionEvent:
            // As these events just have to go through all the handlers, we can succeed the promise here
            promise?.succeed(())
            
        default:
            context.triggerUserOutboundEvent(event, promise: promise)
        }
    }
}
