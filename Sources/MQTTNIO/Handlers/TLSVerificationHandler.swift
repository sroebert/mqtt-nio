import NIO
import NIOSSL
import NIOTLS
import NIOConcurrencyHelpers
import Logging

class TLSVerificationHandler: ChannelInboundHandler, RemovableChannelHandler {
    
    // MARK: - Types
    
    typealias InboundIn = Any
    
    // MARK: - Vars
    
    let logger: Logger
    let lock = Lock()
    private var verificationPromise: EventLoopPromise<Void>!
    
    // MARK: - Init
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - Utils
    
    func verify() -> EventLoopFuture<Void> {
        return lock.withLock { verificationPromise.futureResult }
    }
    
    // MARK: - ChannelInboundHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        lock.withLockVoid {
            verificationPromise = context.eventLoop.makePromise()
            verificationPromise.futureResult.recover { error in
                context.fireErrorCaught(error)
            }.whenComplete { _ in
                context.pipeline.removeHandler(self, promise: nil)
            }
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Failed to succesfully verify TLS", metadata: [
            "error": "\(error)"
        ])
        
        lock.withLockVoid {
            verificationPromise.fail(error)
        }
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard case TLSUserEvent.handshakeCompleted(let tlsProtocol) = event else {
            context.fireUserInboundEventTriggered(event)
            return
        }
        
        logger.debug("TLS handshake completed", metadata: [
            "protocol": .string(tlsProtocol ?? "none")
        ])
        
        lock.withLockVoid {
            verificationPromise.succeed(())
        }
    }
}
