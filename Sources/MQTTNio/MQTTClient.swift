import NIO
import Logging

public protocol MQTTClient {
    var logger: Logger { get }
    var eventLoop: EventLoop { get }
    
    func publish(_ message: MQTTMessage, retryInterval: TimeAmount) -> EventLoopFuture<Void>
    
    func subscribe(to topics: [String]) -> EventLoopFuture<Void>
    func unsubscribe(from topics: [String]) -> EventLoopFuture<Void>
    
    func withConnection<T>(_ closure: @escaping (MQTTConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T>
}

extension MQTTClient {
    public func publish(_ message: MQTTMessage) -> EventLoopFuture<Void> {
        return publish(message, retryInterval: .seconds(5))
    }
}
