import NIO
import NIOConcurrencyHelpers
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    struct DeinitError: Error {}
    
    // MARK: - Vars
    
    static let defaultMaxInflightEntries = 20
    
    var version: MQTTProtocolVersion
    var brokerConfiguration = MQTTBrokerConfiguration()
    
    let eventLoop: EventLoop
    let logger: Logger
    var maxInflightEntries = MQTTRequestHandler.defaultMaxInflightEntries
    
    private let lock = Lock()

    private var entriesInflight: [AnyEntry] = []
    private var entriesQueue: [AnyEntry] = []
    
    private var nextPacketIdentifier: UInt16 = 1
    
    private var isActive: Bool = false
    
    private weak var channel: Channel?
    
    // MARK: - Init

    public init(
        eventLoop: EventLoop,
        version: MQTTProtocolVersion,
        logger: Logger
    ) {
        self.eventLoop = eventLoop
        self.version = version
        self.logger = logger
    }
    
    // MARK: - Queue
    
    func perform<Request: MQTTRequest>(_ request: Request) -> EventLoopFuture<Request.Value> {
        let promise = eventLoop.makePromise(of: Request.Value.self)
        let entry = Entry(request: request, promise: promise)
        lock.withLockVoid {
            entriesQueue.append(entry)
        }
        
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
    
    func failEntries() {
        eventLoop.execute {
            self.entriesInflight.forEach { $0.fail(with: DeinitError()) }
            
            let entriesQueue = self.lock.withLock { self.entriesQueue }
            entriesQueue.forEach { $0.fail(with: DeinitError()) }
        }
    }
    
    // MARK: - ChannelDuplexHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        channel = context.channel
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        forEachEntry(with: context) { entry, requestContext in
            entry.disconnected(context: requestContext)
        }
        
        channel = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        var didProcess = false
        withRequestContext(in: context) { requestContext in
            for (index, entry) in entriesInflight.enumerated() {
                let result = entry.process(context: requestContext, packet: packet)
                switch result {
                case .unprocessed:
                    continue
                    
                case .processed(completed: let completed):
                    if completed {
                        entriesInflight.remove(at: index)
                    }
                    
                    didProcess = true
                    break
                }
            }
            
            startQueuedEntries(context: requestContext)
        }
        
        if !didProcess {
            context.fireChannelRead(data)
        }
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case MQTTConnectionEvent.didConnect(let isSessionPresent):
            isActive = true
            forEachEntry(with: context) { entry, requestContext in
                entry.connected(context: requestContext, isSessionPresent: isSessionPresent)
            }
            
        case MQTTConnectionEvent.willDisconnect:
            isActive = false
            forEachEntry(with: context) { entry, requestContext in
                entry.disconnected(context: requestContext)
            }
            
        default:
            break
        }
        
        context.triggerUserOutboundEvent(event, promise: promise)
    }
    
    // MARK: - Utils
    
    private func getQueuedEntry() -> AnyEntry? {
        return lock.withLock {
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
        
        var version: MQTTProtocolVersion {
            return handler.version
        }
        
        var brokerConfiguration: MQTTBrokerConfiguration {
            return handler.brokerConfiguration
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
    private enum ProcessResult {
        case unprocessed
        case processed(completed: Bool)
    }
    
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
        
        func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> ProcessResult {
            fatalError("Should be implemented in subclass")
        }
        
        func handleEvent(context: MQTTRequestContext, event: Any) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func disconnected(context: MQTTRequestContext) -> Bool {
            fatalError("Should be implemented in subclass")
        }
        
        func connected(context: MQTTRequestContext, isSessionPresent: Bool) -> Bool {
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
        
        override func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> ProcessResult {
            guard let result = request.process(context: context, packet: packet) else {
                return .unprocessed
            }
            
            let completed = handle(result)
            return .processed(completed: completed)
        }
        
        override func handleEvent(context: MQTTRequestContext, event: Any) -> Bool {
            handle(request.handleEvent(context: context, event: event))
        }
        
        override func disconnected(context: MQTTRequestContext) -> Bool {
            handle(request.disconnected(context: context))
        }
        
        override func connected(context: MQTTRequestContext, isSessionPresent: Bool) -> Bool {
            handle(request.connected(context: context, isSessionPresent: isSessionPresent))
        }
    }
}
