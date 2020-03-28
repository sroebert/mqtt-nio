import NIO
import Logging

final class MQTTPacketTypeSerializer: ChannelOutboundHandler {
    
    // MARK: - Properties
    
    let logger: Logger?
    
    // MARK: - Init
    
    init(logger: Logger? = nil) {
        self.logger = logger
    }
    
    // MARK: - ChannelOutboundHandler
    
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let outbound = unwrapOutboundIn(data)
        do {
            let packet = try outbound.serialize()
            context.write(wrapOutboundOut(packet), promise: promise)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
        
        context.channel.eventLoop.assertInEventLoop()
    }
}
