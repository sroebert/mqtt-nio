import NIO
import Logging

final class MQTTErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Uncaught error: \(error)")
        context.close(promise: nil)
        context.fireErrorCaught(error)
    }
}
