import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTRequestContext
    typealias OutboundOut = MQTTPacket.Outbound

    private var inflight: [MQTTRequestContext]
    let logger: Logger

    public init(logger: Logger) {
        self.inflight = []
        self.logger = logger
    }

    private func _channelRead(context: ChannelHandlerContext, data: NIOAny) throws {
        let packet = unwrapInboundIn(data)
        guard let index = inflight.firstIndex(where: { $0.delegate.shouldProcess(packet) }) else {
            // discard packet
            return
        }
        
        let request = inflight[index]
        let action = try request.delegate.process(packet)
        
        if let response = action.response {
            context.writeAndFlush(wrapOutboundOut(response), promise: nil)
        }
        
        switch action.nextStatus {
        case .pending:
            break
            
        case .success:
            inflight.remove(at: index)
            request.promise.succeed(())
            
        case .failure(let error):
            inflight.remove(at: index)
            request.promise.fail(error)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            try _channelRead(context: context, data: data)
        } catch {
            errorCaught(context: context, error: error)
        }
        
        // Regardless of error, also pass the message downstream; this makes sure subscribers are notified
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let request = unwrapOutboundIn(data)
        
        let action: MQTTRequestAction
        do {
            action = try request.delegate.start()
            if let response = action.response {
                context.writeAndFlush(wrapOutboundOut(response), promise: promise)
            }
            
        } catch {
            promise?.fail(error)
            errorCaught(context: context, error: error)
            
            action = .failure(error)
        }
        
        switch action.nextStatus {
        case .pending:
            inflight.append(request)
            
        case .success:
            request.promise.succeed(())
            
        case .failure(let error):
            request.promise.fail(error)
        }
    }

    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        let disconnect = MQTTPacket.Disconnect()
        context.writeAndFlush(wrapOutboundOut(disconnect), promise: nil)
        context.close(mode: mode, promise: promise)

        for request in inflight {
            request.promise.fail(MQTTConnectionError.connectionClosed)
        }
        inflight.removeAll()
    }
    
    // MARK: - Utils
    
    
}

final class MQTTRequestContext {
    let delegate: MQTTRequest
    let promise: EventLoopPromise<Void>
    
    init(delegate: MQTTRequest, promise: EventLoopPromise<Void>) {
        self.delegate = delegate
        self.promise = promise
    }
}
