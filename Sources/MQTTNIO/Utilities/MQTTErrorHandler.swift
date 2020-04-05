import NIO
import NIOSSL
import Logging

final class MQTTErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Uncaught error: \(error)")
        
        // We ignore unclean shutdowns, which could be caused by servers not sending `close_notify`
        if let sslError = error as? NIOSSLError, case .uncleanShutdown = sslError {
            return
        }
        
        // TODO: Forward to error listeners
        
        context.close(promise: nil)
    }
}
