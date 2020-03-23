import NIO
import Logging

final class MQTTRequestHandler: ChannelDuplexHandler {
    typealias InboundIn = MQTTPacket
    typealias OutboundIn = MQTTRequestContext
    typealias OutboundOut = MQTTPacket

    private var inflight: [MQTTRequestContext]
    let logger: Logger

    public init(logger: Logger) {
        self.inflight = []
        self.logger = logger
    }

    private func _channelRead(context: ChannelHandlerContext, data: NIOAny) throws {
        let packet = unwrapInboundIn(data)
        guard let index = try inflight.firstIndex(where: { try $0.delegate.shouldProcess(packet) }) else {
            // discard packet
            return
        }
        
        let request = inflight[index]
        
        var responses: [MQTTPacket] = []
        let result = try request.delegate.process(packet, appendResponse: { packet in
            responses.append(packet)
        })
        
        if !responses.isEmpty {
            for response in responses {
                context.write(wrapOutboundOut(response), promise: nil)
            }
            context.flush()
        }
        
        switch result {
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
        inflight.append(request)
        
        do {
            let packet = try request.delegate.start()
            context.writeAndFlush(wrapOutboundOut(packet), promise: promise)
        } catch {
            promise?.fail(error)
            errorCaught(context: context, error: error)
        }
    }

    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        let disconnect = try! MQTTPacket.Disconnect().message()
        context.writeAndFlush(wrapOutboundOut(disconnect), promise: nil)
        context.close(mode: mode, promise: promise)

        for request in inflight {
            request.promise.fail(MQTTConnectionError.connectionClosed)
        }
        inflight.removeAll()
    }
}

final class MQTTRequestContext {
    let delegate: MQTTRequest
    let promise: EventLoopPromise<Void>
    
    init(delegate: MQTTRequest, promise: EventLoopPromise<Void>) {
        self.delegate = delegate
        self.promise = promise
    }
}
