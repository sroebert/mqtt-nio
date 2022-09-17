import NIO
#if canImport(NIOSSL)
import NIOSSL
#endif
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
        // This should use `canImport(NIOSSL)`, will change when it works with SwiftUI previews.
        #if os(macOS) || os(Linux)
        // We ignore unclean shutdowns, which could be caused by servers not sending `close_notify`
        if let sslError = error as? NIOSSLError, case .uncleanShutdown = sslError {
            return
        }
        #endif
        
        logger.error("Uncaught error: \(error)")
        
        delegate?.mttErrorHandler(self, caughtError: error, channel: context.channel)
    }
}

#if swift(>=5.5) && canImport(_Concurrency)
extension MQTTErrorHandler: @unchecked MQTTSendable {}
#endif
