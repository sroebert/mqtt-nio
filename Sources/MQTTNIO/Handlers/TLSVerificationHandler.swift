import NIO
import NIOSSL
import NIOTLS
import Logging

/// Handler for verifying the SSL connection with the broker.
final class TLSVerificationHandler: ChannelInboundHandler, RemovableChannelHandler {
    
    // MARK: - Types
    
    typealias InboundIn = Any
    
    // MARK: - Vars
    
    let logger: Logger
    private var verificationPromise: EventLoopPromise<Void>!
    
    // MARK: - Init
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - Utils
    
    func verify() -> EventLoopFuture<Void> {
        return verificationPromise.futureResult
    }
    
    // MARK: - ChannelInboundHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        verificationPromise = context.eventLoop.makePromise()
        verificationPromise.futureResult.recover { error in
            context.fireErrorCaught(error)
        }.whenComplete { _ in
            context.pipeline.removeHandler(self, promise: nil)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Failed to succesfully verify TLS", metadata: [
            "error": "\(error)"
        ])
        
        verificationPromise.fail(error)
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard case TLSUserEvent.handshakeCompleted(let tlsProtocol) = event else {
            context.fireUserInboundEventTriggered(event)
            return
        }
        
        logger.debug("TLS handshake completed", metadata: [
            "protocol": .string(tlsProtocol ?? "none")
        ])
        
        verificationPromise.succeed(())
    }
}
