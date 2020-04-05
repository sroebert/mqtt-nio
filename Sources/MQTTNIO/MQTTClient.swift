import NIO
import NIOConcurrencyHelpers
import Logging

public class MQTTClient: MQTTConnectionDelegate, MQTTSubscriptionsHandlerDelegate {
    
    // MARK: - Vars
    
    private var _configuration: MQTTConfiguration
    var configuration: MQTTConfiguration {
        get {
            return lock.withLock { _configuration }
        }
        set {
            lock.withLockVoid {
                _configuration = newValue
            }
        }
    }
    
    let eventLoopGroup: EventLoopGroup
    let logger: Logger
    
    private let lock = Lock()
    private var connection: MQTTConnection?
    
    private let connectionEventLoop: EventLoop
    private let callbackEventLoop: EventLoop
    
    private let requestHandler: MQTTRequestHandler
    private let subscriptionsHandler: MQTTSubscriptionsHandler
    
    private let connectListeners: CallbackList<(MQTTClient, MQTTConnectResponse)>
    private let disconnectListeners: CallbackList<(MQTTClient, MQTTDisconnectReason)>
    private let messageListeners: CallbackList<(MQTTClient, MQTTMessage)>
    
    // MARK: - Init
    
    public init(
        configuration: MQTTConfiguration,
        eventLoopGroup: EventLoopGroup,
        logger: Logger = .init(label: "nl.roebert.MQTTNio"))
    {
        _configuration = configuration
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        
        connectionEventLoop = eventLoopGroup.next()
        callbackEventLoop = eventLoopGroup.next()
        
        requestHandler = MQTTRequestHandler(logger: logger, eventLoop: connectionEventLoop)
        subscriptionsHandler = MQTTSubscriptionsHandler(logger: logger)
        
        connectListeners = CallbackList(eventLoop: callbackEventLoop)
        disconnectListeners = CallbackList(eventLoop: callbackEventLoop)
        messageListeners = CallbackList(eventLoop: callbackEventLoop)
        
        subscriptionsHandler.delegate = self
    }
    
    // MARK: - Connection
    
    // TODO
//    private var connectionState: MQTTConnection.State? {
//        return lock.withLock { connection?.state }
//    }
//
//    public var isConnecting: Bool {
//        let state = connectionState
//        return [.idle, .connecting, .waitingForReconnect].contains(state)
//    }
//
//    public var isConnected: Bool {
//        let state = connectionState
//        return state == .ready
//    }
    
    @discardableResult
    public func connect() -> EventLoopFuture<Void> {
        return lock.withLock {
            guard connection == nil else {
                return connectionEventLoop.makeSucceededFuture(())
            }
            
            let connection = MQTTConnection(
                eventLoop: connectionEventLoop,
                configuration: _configuration,
                requestHandler: requestHandler,
                subscriptionsHandler: subscriptionsHandler,
                logger: logger
            )
            connection.delegate = self
            self.connection = connection
            
            return connection.firstConnectFuture
        }
    }
    
    @discardableResult
    public func disconnect() -> EventLoopFuture<Void> {
        return lock.withLock {
            guard let connection = connection else {
                return connectionEventLoop.makeSucceededFuture(())
            }
            
            self.connection = nil
            return connection.close()
        }
    }
    
    // MARK: - Publish
    
    @discardableResult
    public func publish(_ message: MQTTMessage) -> EventLoopFuture<Void> {
        let retryInterval = configuration.publishRetryInterval
        let request = MQTTPublishRequest(message: message, retryInterval: retryInterval)
        return requestHandler.perform(request)
    }
    
    @discardableResult
    public func publish(
        topic: String,
        payload: ByteBuffer? = nil,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false
    ) -> EventLoopFuture<Void> {
        let message = MQTTMessage(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain
        )
        return publish(message)
    }
    
    @discardableResult
    public func publish(
        topic: String,
        payload: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false
    ) -> EventLoopFuture<Void> {
        let message = MQTTMessage(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain
        )
        return publish(message)
    }
    
    // MARK: - Subscriptions
    
    @discardableResult
    public func subscribe(to subscriptions: [MQTTSubscription]) -> EventLoopFuture<[MQTTSubscriptionResult]> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTSubscribeRequest(subscriptions: subscriptions, timeoutInterval: timeoutInterval)
        return requestHandler.perform(request)
    }
    
    @discardableResult
    public func subscribe(to topic: String, qos: MQTTQoS = .atMostOnce) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: [.init(topic: topic, qos: qos)]).map { $0[0] }
    }
    
    @discardableResult
    public func subscribe(to topics: [String]) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: topics.map { .init(topic: $0) }).map { $0[0] }
    }
    
    @discardableResult
    func unsubscribe(from topics: [String]) -> EventLoopFuture<Void> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTUnsubscribeRequest(topics: topics, timeoutInterval: timeoutInterval)
        return requestHandler.perform(request)
    }
    
    @discardableResult
    public func unsubscribe(from topic: String) -> EventLoopFuture<Void> {
        return unsubscribe(from: [topic])
    }
    
    // MARK: - Listeners
    
    @discardableResult
    public func addConnectListener(_ listener: @escaping MQTTConnectListener) -> MQTTListenerContext {
        return connectListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    @discardableResult
    public func addDisconnectListener(_ listener: @escaping MQTTDisconnectListener) -> MQTTListenerContext {
        return disconnectListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    @discardableResult
    public func addMessageListener(_ listener: @escaping MQTTMessageListener) -> MQTTListenerContext {
        return messageListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    // MARK: - MQTTConnectionDelegate
    
    func mqttConnection(_ connection: MQTTConnection, didConnectWith response: MQTTConnectResponse) {
        connectListeners.emit(arguments: (self, response))
    }
    
    func mqttConnection(_ connection: MQTTConnection, didDisconnectWith reason: MQTTDisconnectReason) {
        disconnectListeners.emit(arguments: (self, reason))
    }
    
    // MARK: - MQTTSubscriptionsHandlerDelegate
    
    func mqttSubscriptionsHandler(_ handler: MQTTSubscriptionsHandler, didReceiveMessage message: MQTTMessage) {
        messageListeners.emit(arguments: (self, message))
    }
}
