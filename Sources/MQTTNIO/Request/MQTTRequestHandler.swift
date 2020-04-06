import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = Never
    typealias OutboundOut = MQTTPacket.Outbound
    
    struct DeinitError: Error {}
    
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
    
    deinit {
        entriesInflight.forEach { $0.fail(with: DeinitError()) }
        entriesQueue.forEach { $0.fail(with: DeinitError()) }
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
        disconnectEntries(context: context)
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
    
    private func withRequestContext(in context: ChannelHandlerContext, _ execute: (MQTTRequestContext) -> Void) {
        let requestContext = RequestContext(handler: self, context: context)
        execute(requestContext)
        if requestContext.didWrite {
            context.flush()
        }
    }
    
    private func forEachEntry(with context: ChannelHandlerContext, _ execute: (AnyEntry, MQTTRequestContext) -> Bool) {
        withRequestContext(in: context) { requestContext in
            entriesInflight = entriesInflight.filter { entry in
                !execute(entry, requestContext)
            }
            
            startQueuedEntries(context: requestContext)
        }
    }
    
    private func updateIsActive(_ isActive: Bool, context: ChannelHandlerContext) {
        logger.trace("MQTTRequestHandler changed active state", metadata: [
            "isActive": .stringConvertible(isActive)
        ])
        
        self.isActive = isActive
        if isActive {
            connectEntries(context: context)
        } else {
            disconnectEntries(context: context)
        }
    }
    
    private func disconnectEntries(context: ChannelHandlerContext) {
        forEachEntry(with: context) { entry, requestContext in
            entry.disconnected(context: requestContext)
        }
    }
    
    private func connectEntries(context: ChannelHandlerContext) {
        forEachEntry(with: context) { entry, requestContext in
            entry.connected(context: requestContext)
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
        private(set) var didWrite: Bool = false
        let handler: MQTTRequestHandler
        let context: ChannelHandlerContext
        
        init(handler: MQTTRequestHandler, context: ChannelHandlerContext) {
            self.handler = handler
            self.context = context
        }
        
        var logger: Logger {
            return handler.logger
        }
        
        func write(_ outbound: MQTTPacket.Outbound) {
            context.write(handler.wrapOutboundOut(outbound), promise: nil)
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
            return scheduled
        }
    }
}

extension MQTTRequestHandler {
    private class AnyEntry {
        func fail(with error: Error) {
            fatalError("Should be implemented in subclass")
        }
        
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
        
        func disconnected(context: MQTTRequestContext) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func connected(context: MQTTRequestContext) -> Bool {
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
        
        override func fail(with error: Error) {
            promise.fail(error)
        }
        
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
        
        override func disconnected(context: MQTTRequestContext) -> Bool {
            handle(request.disconnected(context: context))
        }
        
        override func connected(context: MQTTRequestContext) -> Bool {
            handle(request.connected(context: context))
        }
    }
}