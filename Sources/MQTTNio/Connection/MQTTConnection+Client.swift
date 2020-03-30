import NIO
import Logging

extension MQTTConnection: MQTTClient {
    
    // MARK: - MQTTClient
    
    @discardableResult
    public func publish(_ message: MQTTMessage, retryInterval: TimeAmount) -> EventLoopFuture<Void> {
        let request = MQTTPublishRequest(
            message: message,
            retryInterval: retryInterval
        )
        return channel.pipeline.send(request, logger: logger)
    }
    
    @discardableResult
    public func subscribe(to subscriptions: [MQTTSubscription]) -> EventLoopFuture<[MQTTSubscriptionResult]> {
        let request = MQTTSubscribeRequest(subscriptions: subscriptions)
        return channel.pipeline.send(request, logger: logger).map { request.results }
    }
    
    @discardableResult
    public func unsubscribe(from topics: [String]) -> EventLoopFuture<Void> {
        let request = MQTTUnsubscribeRequest(topics: topics)
        return channel.pipeline.send(request, logger: logger)
    }
    
    @discardableResult
    public func addMessageListener(_ listener: @escaping MQTTClientMessageListener) -> MQTTClientMessageListenContext {
        let context = MQTTClientMessageListenContext()
        let entry = MQTTSubscriptionsHandler.ListenerEntry(
            context: context,
            listener: listener
        )
        
        let pipeline = channel.pipeline
        pipeline.addListenerEntry(entry)
        context.stopper = {
            pipeline.removeListenerEntry(entry)
        }
        
        return context
    }

    public func withConnection<T>(_ closure: (MQTTConnection) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        closure(self)
    }
}

fileprivate extension ChannelPipeline {
    @discardableResult
    func addListenerEntry(_ entry: MQTTSubscriptionsHandler.ListenerEntry) -> EventLoopFuture<Void> {
        
        return contextAndHandler(type: MQTTSubscriptionsHandler.self).map { (context, handler) in
            handler.listeners.append(entry)
        }
    }
    
    @discardableResult
    func removeListenerEntry(_ entry: MQTTSubscriptionsHandler.ListenerEntry) -> EventLoopFuture<Void> {
        
        return contextAndHandler(type: MQTTSubscriptionsHandler.self).map { (context, handler) in
            if let index = handler.listeners.firstIndex(where: { $0 === entry }) {
                handler.listeners.remove(at: index)
            }
        }
    }
}
