import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTRequestEntry
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars

    private var maxInflightEntries = 20
    private var entriesInflight: [MQTTRequestEntry] = []
    private var entriesQueue: [MQTTRequestEntry] = []
    
    private var nextPacketIdentifier: UInt16 = 1
    
    private var isActive: Bool = false
    
    private weak var channel: Channel?
    
    let logger: Logger
    
    // MARK: - Init

    public init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - ChannelDuplexHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        channel = context.channel
        updateIsActive(true, context: context)
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        updateIsActive(false, context: context)
        channel = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        forEachRequest(with: context) { request, context in
            request.process(context: context, packet: packet)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let entry = unwrapOutboundIn(data)
        
        entriesQueue.append(entry)
        withRequestContext(in: context) { requestContext in
            startQueuedEntries(context: requestContext)
        }
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        switch event {
        case let requestEvent as RequestEvent:
            forEachRequest(with: context) { request, requestContext in
                request.handleEvent(context: requestContext, event: requestEvent.event)
            }
            
        default:
            context.triggerUserOutboundEvent(event, promise: promise)
        }
    }

    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        updateIsActive(false, context: context)
        
        let disconnect = MQTTPacket.Disconnect()
        context.writeAndFlush(wrapOutboundOut(disconnect), promise: nil)
        context.close(mode: mode, promise: promise)
    }
    
    // MARK: - Utils
    
    private func startQueuedEntries(context: MQTTRequestContext) {
        while entriesInflight.count < maxInflightEntries && !entriesQueue.isEmpty {
            let entry = entriesQueue.removeFirst()
            
            let result = entry.request.start(context: context)
            if !entry.handle(result) {
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
    
    private func forEachRequest(with context: ChannelHandlerContext, _ execute: (MQTTRequest, MQTTRequestContext) -> MQTTRequestResult) {
        withRequestContext(in: context) { requestContext in
            entriesInflight = entriesInflight.reduce([]) { entries, entry in
                let result = execute(entry.request, requestContext)
                guard !entry.handle(result) else {
                    return entries
                }
                
                var entries = entries
                entries.append(entry)
                return entries
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
        forEachRequest(with: context) { request, requestContext in
            request.pause(context: requestContext)
            return .pending
        }
    }
    
    private func resumeEntries(context: ChannelHandlerContext) {
        forEachRequest(with: context) { request, requestContext in
            request.resume(context: requestContext)
        }
    }
}

extension MQTTRequestHandler {
    private struct RequestEvent {
        var event: Any
    }
    
    private class RequestContext: MQTTRequestContext {
        var didWrite: Bool = false
        var handler: MQTTRequestHandler
        var context: ChannelHandlerContext
        
        init(handler: MQTTRequestHandler, context: ChannelHandlerContext) {
            self.handler = handler
            self.context = context
        }
        
        func write(_ outbound: MQTTPacket.Outbound) {
            context.write(handler.wrapOutboundOut(outbound), promise: nil)
            didWrite = true
        }
        
        func getNextPacketId() -> UInt16 {
            return handler.getNextPacketId()
        }
        
        func scheduleEvent(_ event: Any, in time: TimeAmount) -> Scheduled<Void> {
            return context.eventLoop.scheduleTask(in: time) { [weak handler] in
                let requestEvent = RequestEvent(event: event)
                handler?.channel?.triggerUserOutboundEvent(requestEvent, promise: nil)
            }
        }
    }
}

final class MQTTRequestEntry {
    let request: MQTTRequest
    let promise: EventLoopPromise<Void>
    
    init(request: MQTTRequest, promise: EventLoopPromise<Void>) {
        self.request = request
        self.promise = promise
    }
    
    fileprivate func handle(_ result: MQTTRequestResult) -> Bool {
        switch result {
        case .pending:
            return false
            
        case .success:
            promise.succeed(())
            return true
            
        case .failure(let error):
            promise.fail(error)
            return true
        }
    }
}
