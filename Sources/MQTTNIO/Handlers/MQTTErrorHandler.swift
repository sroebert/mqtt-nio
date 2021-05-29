import NIO
import NIOSSL
import Logging

protocol MQTTErrorHandlerDelegate: AnyObject {
    func mttErrorHandler(_ handler: MQTTErrorHandler, caughtError error: Error, channel: Channel)
}

final class MQTTErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    let logger: Logger
    
    weak var delegate: MQTTErrorHandlerDelegate?
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Uncaught error: \(error)")
        
        // We ignore unclean shutdowns, which could be caused by servers not sending `close_notify`
        if let sslError = error as? NIOSSLError, case .uncleanShutdown = sslError {
            return
        }
        
        delegate?.mttErrorHandler(self, caughtError: error, channel: context.channel)
    }
}
