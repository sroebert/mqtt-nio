import NIO
import Logging

final class MQTTPacketTypeSerializer: ChannelOutboundHandler, MQTTPacketOutboundIDProvider {
    
    // MARK: - Properties
    
    let logger: Logger?
    
    private var nextPacketIdentifier: UInt16 = 0
    
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
            let packet = try outbound.serialize(using: self)
            context.write(wrapOutboundOut(packet), promise: promise)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
        
        context.channel.eventLoop.assertInEventLoop()
    }
    
    // MARK: - MQTTPacketOutboundIDProvider
    
    func getNextPacketId() -> UInt16 {
        let identifier = nextPacketIdentifier
        nextPacketIdentifier &+= 1
        return identifier
    }
}
