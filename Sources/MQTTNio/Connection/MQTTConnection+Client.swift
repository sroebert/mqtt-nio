import NIO
import Logging

extension MQTTConnection: MQTTClient {
    public func publish(_ message: MQTTMessage) -> EventLoopFuture<Void> {
        fatalError()
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
