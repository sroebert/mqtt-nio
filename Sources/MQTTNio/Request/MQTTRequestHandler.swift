import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler, MQTTRequestIdProvider {
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTRequestContext
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars

    private var inflight: [MQTTRequestContext]
    private var nextPacketIdentifier: UInt16 = 1
    
    let logger: Logger
    
    // MARK: - Init

    public init(logger: Logger) {
        self.inflight = []
        self.logger = logger
    }
    
    // MARK: - ChannelDuplexHandler

    private func _channelRead(context: ChannelHandlerContext, data: NIOAny) throws {
        let packet = unwrapInboundIn(data)
        
//        var didRespond: Bool = false
//        defer {
//            if didRespond {
//                context.flush()
//            }
//        }
        
        for (index, requestContext) in inflight.enumerated() {
            let action = try requestContext.request.process(packet)
            
            if let response = action.response {
//                didRespond = true
                context.writeAndFlush(wrapOutboundOut(response), promise: nil)
            }
            
            switch action.nextStatus {
            case .pending:
                break
                
            case .success:
                inflight.remove(at: index)
                requestContext.promise.succeed(())
                return
                
            case .failure(let error):
                inflight.remove(at: index)
                requestContext.promise.fail(error)
                return
            }
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
        let requestContext = unwrapOutboundIn(data)
        
        let action: MQTTRequestAction
        do {
            action = try requestContext.request.start(using: self)
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
            inflight.append(requestContext)
            
        case .success:
            requestContext.promise.succeed(())
            
        case .failure(let error):
            requestContext.promise.fail(error)
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
    
    // MARK: - MQTTRequestIdProvider
    
    func getNextPacketId() -> UInt16 {
        let identifier = nextPacketIdentifier
        nextPacketIdentifier &+= 1
        
        // Make sure we don't use 0 as an id
        if nextPacketIdentifier == 0 {
            nextPacketIdentifier += 1
        }
        
        return identifier
    }
}

final class MQTTRequestContext {
    let request: MQTTRequest
    let promise: EventLoopPromise<Void>
    
    init(request: MQTTRequest, promise: EventLoopPromise<Void>) {
        self.request = request
        self.promise = promise
    }
}
