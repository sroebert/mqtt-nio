import NIO
import Logging

final class MQTTPingHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTRequestEntry
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let logger: Logger
    let keepAliveInterval: TimeAmount
    let reschedulePings: Bool
    
    private weak var channel: Channel?
    private var scheduledPing: Scheduled<Void>?
    
    // MARK: - Init
    
    init(logger: Logger, keepAliveInterval: TimeAmount, reschedulePings: Bool = true) {
        self.logger = logger
        self.keepAliveInterval = keepAliveInterval
        self.reschedulePings = reschedulePings
    }
    
    // MARK: - ChannelDuplexHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        channel = context.channel
        schedulePingRequest(in: context.eventLoop)
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        unschedulePingRequest()
        channel = nil
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        // Reschedule ping request as we are already sending a packet
        if reschedulePings && scheduledPing != nil {
            schedulePingRequest(in: context.eventLoop)
        }
        
        // Forward
        context.write(data, promise: promise)
    }
    
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        unschedulePingRequest()
        
        context.close(mode: mode, promise: promise)
    }
    
    // MARK: - Utils
    
    private func schedulePingRequest(in eventLoop: EventLoop) {
        unschedulePingRequest()
        
        guard keepAliveInterval.nanoseconds > 0 else {
            return
        }
        
        scheduledPing = eventLoop.scheduleTask(in: keepAliveInterval) { [weak self] in
            self?.performPingRequest()
        }
    }
    
    private func unschedulePingRequest() {
        scheduledPing?.cancel()
        scheduledPing = nil
    }
    
    private func performPingRequest() {
        guard let channel = channel, scheduledPing != nil else {
            return
        }
        
        let promise = channel.eventLoop.makePromise(of: Void.self)
        let request = MQTTRequestEntry(request: MQTTPingRequest(keepAliveInterval: keepAliveInterval), promise: promise)
        
        channel.write(request).cascadeFailure(to: promise)
        channel.flush()
        
        promise.futureResult.whenFailure { [weak self] error in
            self?.unschedulePingRequest()
            self?.channel?.close(mode: .all, promise: nil)
        }
    }
}
