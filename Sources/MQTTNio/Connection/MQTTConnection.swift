import Logging
import NIO

public final class MQTTConnection {
    let channel: Channel
    
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    public var closeFuture: EventLoopFuture<Void> {
        return channel.closeFuture
    }
    
    public var logger: Logger

    private var didClose: Bool

    public var isClosed: Bool {
        return !channel.isActive
    }
    
    init(channel: Channel, logger: Logger) {
        self.channel = channel
        self.logger = logger
        didClose = false
    }
    
    public func close() -> EventLoopFuture<Void> {
        guard !didClose else {
            return eventLoop.makeSucceededFuture(())
        }
        didClose = true
        if !isClosed {
            return channel.close(mode: .all)
        } else {
            return eventLoop.makeSucceededFuture(())
        }
    }
    
    deinit {
        assert(didClose, "MQTTConnection deinitialized before being closed.")
    }
}
