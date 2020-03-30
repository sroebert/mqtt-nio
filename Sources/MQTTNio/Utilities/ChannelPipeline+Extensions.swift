import NIO
import Logging

extension ChannelPipeline {
    func send(_ request: MQTTRequest, logger: Logger) -> EventLoopFuture<Void> {
        request.log(to: logger)
        
        return contextAndHandler(type: MQTTRequestHandler.self).flatMap { (context, handler) in
            handler.perform(request, context: context)
        }
    }
    
    func contextAndHandler<Handler: ChannelHandler>(type handlerType: Handler.Type) -> EventLoopFuture<(context: ChannelHandlerContext, handler: Handler)> {
        
        return context(handlerType: Handler.self).map { context in
            guard let handler = context.handler as? Handler else {
                preconditionFailure("Expected channel handler of type \(Handler.self), got \(type(of: context.handler)) instead.")
            }
            return (context: context, handler: handler)
        }
    }
}

