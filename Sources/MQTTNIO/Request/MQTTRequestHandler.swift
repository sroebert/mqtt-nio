import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = Never
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let logger: Logger
    let eventLoop: EventLoop

    private var maxInflightEntries = 20
    private var entriesInflight: [AnyEntry] = []
    private var entriesQueue: [AnyEntry] = []
    
    private var nextPacketIdentifier: UInt16 = 1
    
    private var isActive: Bool = false
    
    private weak var channel: Channel?
    
    // MARK: - Init

    public init(logger: Logger, eventLoop: EventLoop) {
        self.logger = logger
        self.eventLoop = eventLoop
    }
    
    // MARK: - Queue
    
    func perform<Request: MQTTRequest>(_ request: Request) -> EventLoopFuture<Request.Value> {
        let promise = eventLoop.makePromise(of: Request.Value.self)
        let entry = Entry(request: request, promise: promise)
        entriesQueue.append(entry)
        
        channel?.pipeline.context(handler: self).whenSuccess { [weak self] context in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.withRequestContext(in: context) { requestContext in
                strongSelf.startQueuedEntries(context: requestContext)
            }
        }
        
        return promise.futureResult
    }
    
    // MARK: - ChannelDuplexHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        channel = context.channel
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        channel = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        forEachEntry(with: context) { entry, context in
            entry.process(context: context, packet: packet)
        }
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case MQTTConnectionEvent.didConnect:
            updateIsActive(true, context: context)
            
            
        case MQTTConnectionEvent.willDisconnect:
            updateIsActive(false, context: context)
            
        default:
            break
        }
        
        context.triggerUserOutboundEvent(event, promise: promise)
    }

    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        let wasActive = isActive
        
        logger.debug("Triggering willDisconnect event")
        
        context.channel.triggerUserOutboundEvent(MQTTConnectionEvent.willDisconnect).whenComplete { _ in
            // Only send disconnect packet if we succesfully connected before
            guard wasActive else {
                self.logger.debug("Finished disconnecting, not sending Disconnect packet")
                
                context.close(mode: mode, promise: promise)
                return
            }
            
            self.logger.debug("Finished disconnecting, sending Disconnect packet")
            
            let disconnect = MQTTPacket.Disconnect()
            context.writeAndFlush(self.wrapOutboundOut(disconnect)).whenComplete { _ in
                context.close(mode: mode, promise: promise)
            }
        }
    }
    
    // MARK: - Utils
    
    private func getQueuedEntry() -> AnyEntry? {
        // If not active, only return the one that can be send while not active
        if !isActive, let connectIndex = entriesQueue.firstIndex(where: { $0.canPerformInInactiveState }) {
            return entriesQueue.remove(at: connectIndex)
        }
        
        // Otherwise only return something if active and we are allowed to have more inflight entries.
        guard isActive && entriesInflight.count < maxInflightEntries && !entriesQueue.isEmpty else {
            return nil
        }
        return entriesQueue.removeFirst()
    }
    
    private func getInflightEntry() -> AnyEntry? {
        guard !entriesInflight.isEmpty else {
            return nil
        }
        return entriesInflight.removeFirst()
    }
    
    private func startQueuedEntries(context: MQTTRequestContext) {
        while let entry = getQueuedEntry() {
            if !entry.start(context: context) {
                entriesInflight.append(entry)
            }
        }
    }
    
    private func getNextPacketId() -> UInt16 {
        let identifier = nextPacketIdentifier
        nextPacketIdentifier &+= 1
        
        // Make sure we don't use 0 as an id
        if nextPacketIdentifier == 0 {
            nextPacketIdentifier += 1
        }
        
        return identifier
    }
    
    private func withRequestContext(in context: ChannelHandlerContext?, _ execute: (MQTTRequestContext) -> Void) {
        let requestContext = RequestContext(handler: self, context: context)
        execute(requestContext)
        if requestContext.didWrite {
            context?.flush()
        }
    }
    
    private func forEachEntry(with context: ChannelHandlerContext?, _ execute: (AnyEntry, MQTTRequestContext) -> Bool) {
        withRequestContext(in: context) { requestContext in
            entriesInflight = entriesInflight.filter { entry in
                !execute(entry, requestContext)
            }
            
            startQueuedEntries(context: requestContext)
        }
    }
    
    private func updateIsActive(_ isActive: Bool, context: ChannelHandlerContext) {
        guard isActive != self.isActive else {
            return
        }
        
        self.isActive = isActive
        if isActive {
            resumeEntries(context: context)
        } else {
            pauseEntries(context: context)
        }
    }
    
    private func pauseEntries(context: ChannelHandlerContext) {
        forEachEntry(with: context) { entry, requestContext in
            entry.pause(context: requestContext)
            return false
        }
    }
    
    private func resumeEntries(context: ChannelHandlerContext) {
        forEachEntry(with: context) { entry, requestContext in
            entry.resume(context: requestContext)
        }
    }
    
    fileprivate func triggerRequestEvent(_ event: Any, in eventLoop: EventLoop) {
        channel?.pipeline.context(handler: self).whenSuccess { [weak self] context in
            guard let strongSelf = self else {
                return
            }
            strongSelf.logger.trace("Triggered request event", metadata: [
                "event": "\(event)"
            ])
            strongSelf.forEachEntry(with: context) { entry, requestContext in
                entry.handleEvent(context: requestContext, event: event)
            }
        }
    }
}

extension MQTTRequestHandler {
    private class RequestContext: MQTTRequestContext {
        var didWrite: Bool = false
        var handler: MQTTRequestHandler
        var context: ChannelHandlerContext?
        
        init(handler: MQTTRequestHandler, context: ChannelHandlerContext?) {
            self.handler = handler
            self.context = context
        }
        
        var logger: Logger {
            return handler.logger
        }
        
        func write(_ outbound: MQTTPacket.Outbound) {
            if let context = context {
                context.write(handler.wrapOutboundOut(outbound), promise: nil)
            } else {
                logger.notice("Did not send outbound packet, no connection", metadata: [
                    "outbound": "\(outbound)"
                ])
            }
            didWrite = true
        }
        
        func getNextPacketId() -> UInt16 {
            return handler.getNextPacketId()
        }
        
        func scheduleEvent(_ event: Any, in delay: TimeAmount) -> Scheduled<Void> {
            let logger = handler.logger
            logger.trace("Scheduling request event", metadata: [
                "delay": .stringConvertible(delay.nanoseconds / 1_000_000_000),
                "event": "\(event)"
            ])
            
            let eventLoop = handler.eventLoop
            let scheduled = eventLoop.scheduleTask(in: delay) { [weak handler] in
                guard let handler = handler else {
                    return
                }
                handler.triggerRequestEvent(event, in: eventLoop)
            }
            scheduled.futureResult.whenFailure { _ in
                logger.trace("Cancelled scheduled request event", metadata: [
                    "event": "\(event)"
                ])
            }
            return scheduled
        }
    }
}

extension MQTTRequestHandler {
    private class AnyEntry {
        var canPerformInInactiveState: Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func start(context: MQTTRequestContext) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func handleEvent(context: MQTTRequestContext, event: Any) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func pause(context: MQTTRequestContext) {
            fatalError("Should be implemented in subclass")
        }
        
        func resume(context: MQTTRequestContext) -> Bool {
            fatalError("Should be implemented in subclass")
        }
    }
    
    final private class Entry<Request: MQTTRequest>: AnyEntry {
        let request: Request
        let promise: EventLoopPromise<Request.Value>
        
        init(request: Request, promise: EventLoopPromise<Request.Value>) {
            self.request = request
            self.promise = promise
        }
        
        // MARK: - Promise
        
        private func handle(_ result: MQTTRequestResult<Request.Value>) -> Bool {
            guard let promiseResult = result.promiseResult else {
                return false
            }
            promise.completeWith(promiseResult)
            return true
        }
        
        // Forwarding
        
        override var canPerformInInactiveState: Bool {
            return request.canPerformInInactiveState
        }
        
        override func start(context: MQTTRequestContext) -> Bool {
            return handle(request.start(context: context))
        }
        
        override func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> Bool {
            handle(request.process(context: context, packet: packet))
        }
        
        override func handleEvent(context: MQTTRequestContext, event: Any) -> Bool {
            handle(request.handleEvent(context: context, event: event))
        }
        
        override func pause(context: MQTTRequestContext) {
            request.pause(context: context)
        }
        
        override func resume(context: MQTTRequestContext) -> Bool {
            handle(request.resume(context: context))
        }
    }
}
