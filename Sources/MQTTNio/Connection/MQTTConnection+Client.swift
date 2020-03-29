import NIO
import Logging

extension MQTTConnection: MQTTClient {
    public func publish(_ message: MQTTMessage, retryInterval: TimeAmount) -> EventLoopFuture<Void> {
        let request = MQTTPublishRequest(
            message: message,
            retryInterval: retryInterval
        )
        return send(request, logger: logger)
    }
    
    public func subscribe(to topics: [String]) -> EventLoopFuture<Void> {
        fatalError()
    }
    
    public func unsubscribe(from topics: [String]) -> EventLoopFuture<Void> {
        fatalError()
    }

    public func withConnection<T>(_ closure: (MQTTConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        closure(self)
    }
}
