import NIO
import Logging

public final class MQTTClientMessageListenContext {
    var stopper: (() -> Void)?
    
    public func stop() {
        stopper?()
        stopper = nil
    }
}

public typealias MQTTClientMessageListener = (MQTTClientMessageListenContext, MQTTMessage) -> Void

public protocol MQTTClient {
    var logger: Logger { get }
    var eventLoop: EventLoop { get }
    
    @discardableResult
    func publish(_ message: MQTTMessage, retryInterval: TimeAmount) -> EventLoopFuture<Void>
    
    @discardableResult
    func subscribe(to subscriptions: [MQTTSubscription]) -> EventLoopFuture<[MQTTSubscriptionResult]>
    
    @discardableResult
    func unsubscribe(from topics: [String]) -> EventLoopFuture<Void>
    
    @discardableResult
    func addMessageListener(_ listener: @escaping MQTTClientMessageListener) -> MQTTClientMessageListenContext
    
    func withConnection<T>(_ closure: @escaping (MQTTConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T>
}

extension MQTTClient {
    public func subscribe(to topic: String, qos: MQTTQoS = .atMostOnce) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: [.init(topic: topic, qos: qos)]).map { $0[0] }
    }
    
    public func subscribe(to topics: [String]) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: topics.map { .init(topic: $0) }).map { $0[0] }
    }
    
    public func unsubscribe(from topic: String) -> EventLoopFuture<Void> {
        return unsubscribe(from: [topic])
    }
}

public struct MQTTSubscription {
    public var topic: String
    public var qos: MQTTQoS
    
    public init(topic: String, qos: MQTTQoS = .atMostOnce) {
        self.topic = topic
        self.qos = qos
    }
}

public enum MQTTSubscriptionResult {
    case success(MQTTQoS)
    case failure
}

extension MQTTClient {
    public func publish(_ message: MQTTMessage) -> EventLoopFuture<Void> {
        return publish(message, retryInterval: .seconds(5))
    }
}
