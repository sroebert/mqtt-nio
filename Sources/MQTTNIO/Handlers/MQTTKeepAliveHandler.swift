import NIO
import NIOConcurrencyHelpers
import Logging

final class MQTTKeepAliveHandler: ChannelOutboundHandler {
    
    // MARK: - Types
    
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let logger: Logger
    let interval: TimeAmount
    let reschedulePings: Bool
    
    private let lock = Lock()
    private weak var channel: Channel?
    private var scheduledPing: Scheduled<Void>?
    
    // MARK: - Init
    
    init(logger: Logger, interval: TimeAmount, reschedulePings: Bool = true) {
        self.logger = logger
        self.interval = interval
        self.reschedulePings = reschedulePings
    }
    
    // MARK: - ChannelDuplexHandler
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        
        switch event {
        case MQTTConnectionEvent.didConnect:
            lock.withLockVoid {
                schedulePingRequest(in: context.eventLoop)
            }
            
        case MQTTConnectionEvent.willDisconnect:
            lock.withLockVoid {
                unschedulePingRequest()
            }
            
        default:
            break
        }
        
        context.triggerUserOutboundEvent(event, promise: promise)
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        lock.withLockVoid {
            channel = context.channel
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        lock.withLockVoid {
            unschedulePingRequest()
            channel = nil
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        // Reschedule ping request as we are already sending a packet
        if reschedulePings {
            lock.withLockVoid {
                if scheduledPing != nil {
                    schedulePingRequest(in: context.eventLoop)
                }
            }
        }
        
        // Forward
        context.write(data, promise: promise)
    }
    
    // MARK: - Utils
    
    private func schedulePingRequest(in eventLoop: EventLoop) {
        unschedulePingRequest()
        
        guard interval.nanoseconds > 0 else {
            return
        }
        
        scheduledPing = eventLoop.scheduleTask(in: interval) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.performPingRequest()
        }
    }
    
    private func unschedulePingRequest() {
        scheduledPing?.cancel()
        scheduledPing = nil
    }
    
    private func performPingRequest() {
        let optionalChannel = lock.withLock { () -> Channel? in
            guard let channel = channel, scheduledPing != nil else {
                return nil
            }
            return channel
        }
        
        guard let channel = optionalChannel else {
            return
        }
        
        let request = MQTTPingRequest(timeoutInterval: interval)
        channel.pipeline.handler(type: MQTTRequestHandler.self).flatMap {
            $0.perform(request)
        }.whenFailure { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lock.withLockVoid {
                strongSelf.unschedulePingRequest()
            }
            strongSelf.channel?.close(mode: .all, promise: nil)
        }
    }
}
