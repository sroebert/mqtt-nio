import NIO
import NIOSSL
import NIOConcurrencyHelpers
import Logging

/// Client for connecting with an `MQTT` broker.
///
/// This client will be setup using an instance of `MQTTConfiguration`. This configuration
/// can be changed at any point, but most values of this configuration will only be used upon
/// reconnecting with the broker.
///
/// If configured with `.retry` as the reconnect mode, the client will automatically
/// reconnect in case of a connection failure. Any published message will be retried after reconnection.
/// `addConnectListener` and `addDisconnectListener` can be used to listen for
/// changes in the connection.
public class MQTTClient: MQTTConnectionDelegate, MQTTSubscriptionsHandlerDelegate {
    
    // MARK: - Vars
    
    private var _configuration: MQTTConfiguration
    
    /// The configuration of the client.
    ///
    /// When changing values in the configuration, make sure to call `reconnect()` to apply the new values.
    public var configuration: MQTTConfiguration {
        get {
            return lock.withLock { _configuration }
        }
        set {
            lock.withLockVoid {
                _configuration = newValue
            }
        }
    }
    
    /// The `EventLoopGroup` used for the connection with the broker and the callbacks to the listeners.
    let eventLoopGroup: EventLoopGroup
    
    /// Indicates whether the event loop group should be shutdown when this class is deallocated.
    private let shouldShutdownEventLoopGroup: Bool
    
    /// The `Logger` used for logging events from the client.
    let logger: Logger
    
    /// `Lock` for making sure this class is thread safe.
    private let lock = Lock()
    
    /// The connection with the broker.
    private var connection: MQTTConnection?
    
    /// Boolean indicating whether the `connection` is currently connected to a broker.
    private var _isConnected: Bool = false
    
    /// The `EventLoop` used for the connection with the broker.
    private let connectionEventLoop: EventLoop
    
    /// The `EventLoop` used for the calling the listener callbacks.
    private let callbackEventLoop: EventLoop
    
    /// The `MQTTRequestHandler` for the broker connection pipeline.
    private let requestHandler: MQTTRequestHandler
    
    /// The `MQTTSubscriptionsHandler` for the broker connection pipeline.
    private let subscriptionsHandler: MQTTSubscriptionsHandler
    
    /// The list of connect listeners.
    private let connectListeners: CallbackList<(MQTTClient, MQTTConnectResponse)>
    
    /// The list of disconnect listeners.
    private let disconnectListeners: CallbackList<(MQTTClient, MQTTDisconnectReason)>
    
    /// The list of message listeners.
    private let messageListeners: CallbackList<(MQTTClient, MQTTMessage)>
    
    /// The list of error listeners.
    private let errorListeners: CallbackList<(MQTTClient, Error)>
    
    // MARK: - Init
    
    /// Creates an `MQTTClient`
    /// - Parameters:
    ///   - configuration: The configuration for the client.
    ///   - eventLoopGroupProvider: The provider for creating the `EventLoopGroup` used by this client. Either this provides a shared group or indicates the client should create its own group. The default value is to create a new group.
    ///   - logger: The logger for logging connection events. The default value is an instance of the default `Logger`.
    public init(
        configuration: MQTTConfiguration,
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew,
        logger: Logger = .init(label: "nl.roebert.MQTTNio")
    ) {
        _configuration = configuration
        
        switch eventLoopGroupProvider {
        case .createNew:
            eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            shouldShutdownEventLoopGroup = true
            
        case .shared(let eventLoopGroup):
            self.eventLoopGroup = eventLoopGroup
            shouldShutdownEventLoopGroup = false
        }
        self.logger = logger
        
        connectionEventLoop = eventLoopGroup.next()
        callbackEventLoop = eventLoopGroup.next()
        
        requestHandler = MQTTRequestHandler(logger: logger, eventLoop: connectionEventLoop)
        subscriptionsHandler = MQTTSubscriptionsHandler(logger: logger)
        
        connectListeners = CallbackList(eventLoop: callbackEventLoop)
        disconnectListeners = CallbackList(eventLoop: callbackEventLoop)
        messageListeners = CallbackList(eventLoop: callbackEventLoop)
        errorListeners = CallbackList(eventLoop: callbackEventLoop)
        
        subscriptionsHandler.delegate = self
    }
    
    /// Creates an `MQTTClient`
    /// - Parameters:
    ///   - configuration: The configuration for the client.
    ///   - eventLoopGroup: The `EventLoopGroup` to use for connection and callbacks. It will be most efficient to use a group that has at least two separate `EventGroup`s on separate threads. (e.g. `MultiThreadedEventLoopGroup(numberOfThreads: 1)`).
    ///   - logger: The logger for logging connection events. The default value is an instance of the default `Logger`.
    public convenience init(
        configuration: MQTTConfiguration,
        eventLoopGroup: EventLoopGroup,
        logger: Logger = .init(label: "nl.roebert.MQTTNio")
    ) {
        self.init(
            configuration: configuration,
            eventLoopGroupProvider: .shared(eventLoopGroup),
            logger: logger
        )
    }
    
    deinit {
        requestHandler.failEntries()
        
        if shouldShutdownEventLoopGroup {
            try? eventLoopGroup.syncShutdownGracefully()
        }
    }
    
    // MARK: - Connection

    /// Boolean indicating whether the client is currently trying to connect to a broker.
    public var isConnecting: Bool {
        return lock.withLock { connection != nil && !_isConnected }
    }

    /// Boolean indicating whether the client is currently connected with a broker.
    public var isConnected: Bool {
        return lock.withLock { _isConnected }
    }
    
    /// Starts connecting to the broker indicating by the `configuration`.
    /// - Returns: An `EventLoopFuture` for when the connection succeeds or fails.
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
    
    /// Disconnects from the broker.
    /// - Returns: An `EventLoopFuture` for when the disconnection has completed.
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
    
    /// Disconnects and reconnects to the broker, making sure the updating `configuration` values
    /// are in use.
    /// - Returns: An `EventLoopFuture` for when the reconnection succeeds or fails.
    @discardableResult
    public func reconnect() -> EventLoopFuture<Void> {
        return disconnect().flatMap { self.connect() }
    }
    
    // MARK: - Publish
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameter message: The message to publish.
    /// - Returns: An `EventLoopFuture` for when the publishing has completed.
    @discardableResult
    public func publish(_ message: MQTTMessage) -> EventLoopFuture<Void> {
        let retryInterval = configuration.publishRetryInterval
        let request = MQTTPublishRequest(message: message, retryInterval: retryInterval)
        return requestHandler.perform(request)
    }
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The optional payload of the message. The default is `nil`.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    /// - Returns: An `EventLoopFuture` for when the publishing has completed.
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
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameters:
    ///   - topic: The topic for the message.
    ///   - payload: The payload of the message in the form of a string.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    /// - Returns: An `EventLoopFuture` for when the publishing has completed.
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
    
    /// Subscribes to one or more topics on the broker.
    /// - Parameter subscriptions: An array of `MQTTSubscription`s indicating what to subscribe to.
    /// - Returns: An `EventLoopFuture` with an array of `MQTTSubscriptionResult`s indicating the results for each `MQTTSubscription`.
    @discardableResult
    public func subscribe(to subscriptions: [MQTTSubscription]) -> EventLoopFuture<[MQTTSubscriptionResult]> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTSubscribeRequest(subscriptions: subscriptions, timeoutInterval: timeoutInterval)
        return requestHandler.perform(request)
    }
    
    /// Subscribes to a topic with a given QoS.
    /// - Parameters:
    ///   - topic: The topic to subscribe to.
    ///   - qos: The QoS level with which to subscribe. The default value is `.atMostOnce`.
    /// - Returns: An `EventLoopFuture` with the `MQTTSubscriptionResult` indicating the result of the subscription.
    @discardableResult
    public func subscribe(to topic: String, qos: MQTTQoS = .atMostOnce) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: [.init(topic: topic, qos: qos)]).map { $0[0] }
    }
    
    /// Subscribes to one or more topics with the QoS level of `.atMostOnce`.
    /// - Parameter topics: The topics to subscribe to.
    /// - Returns: An `EventLoopFuture` with an array of `MQTTSubscriptionResult`s indicating the results for each `MQTTSubscription`.
    @discardableResult
    public func subscribe(to topics: [String]) -> EventLoopFuture<MQTTSubscriptionResult> {
        return subscribe(to: topics.map { .init(topic: $0) }).map { $0[0] }
    }
    
    /// Unsubscribe from one or more topics.
    /// - Parameter topics: The topics to unsubscribe from.
    /// - Returns: An `EventLoopFuture` for when the unsubscribing has completed.
    @discardableResult
    func unsubscribe(from topics: [String]) -> EventLoopFuture<Void> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTUnsubscribeRequest(topics: topics, timeoutInterval: timeoutInterval)
        return requestHandler.perform(request)
    }
    
    /// Unsubscribe from a topic.
    /// - Parameter topic: The topic to unsubscribe from.
    /// - Returns: An `EventLoopFuture` for when the unsubscribing has completed.
    @discardableResult
    public func unsubscribe(from topic: String) -> EventLoopFuture<Void> {
        return unsubscribe(from: [topic])
    }
    
    // MARK: - Listeners
    
    /// Adds a listener which will be called when the client has connected to a broker.
    /// - Parameter listener: The listener to add.
    /// - Returns: An `MQTTListenerContext` which can be used to stop the listening.
    @discardableResult
    public func addConnectListener(_ listener: @escaping MQTTConnectListener) -> MQTTListenerContext {
        return connectListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    /// Adds a listener which will be called when the client has disconnected from a broker.
    /// - Parameter listener: The listener to add.
    /// - Returns: An `MQTTListenerContext` which can be used to stop the listening.
    @discardableResult
    public func addDisconnectListener(_ listener: @escaping MQTTDisconnectListener) -> MQTTListenerContext {
        return disconnectListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    /// Adds a listener which will be called when the client caught an error.
    /// - Parameter listener: The listener to add.
    /// - Returns: An `MQTTListenerContext` which can be used to stop the listening.
    @discardableResult
    public func addErrorListener(_ listener: @escaping MQTTErrorListener) -> MQTTListenerContext {
        return errorListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    /// Adds a listener which will be called when the client has received an `MQTTMessage`.
    /// - Parameter listener: The listener to add.
    /// - Returns: An `MQTTListenerContext` which can be used to stop the listening.
    @discardableResult
    public func addMessageListener(_ listener: @escaping MQTTMessageListener) -> MQTTListenerContext {
        return messageListeners.append { arguments, context in
            listener(arguments.0, arguments.1, context)
        }
    }
    
    // MARK: - MQTTConnectionDelegate
    
    func mqttConnection(_ connection: MQTTConnection, didConnectWith response: MQTTConnectResponse) {
        lock.withLockVoid {
            _isConnected = true
        }
        
        connectListeners.emit(arguments: (self, response))
    }
    
    func mqttConnection(_ connection: MQTTConnection, didDisconnectWith reason: MQTTDisconnectReason) {
        lock.withLockVoid {
            _isConnected = false
        }
        
        disconnectListeners.emit(arguments: (self, reason))
    }
    
    func mqttConnection(_ connection: MQTTConnection, caughtError error: Error) {
        errorListeners.emit(arguments: (self, error))
    }
    
    // MARK: - MQTTSubscriptionsHandlerDelegate
    
    func mqttSubscriptionsHandler(_ handler: MQTTSubscriptionsHandler, didReceiveMessage message: MQTTMessage) {
        messageListeners.emit(arguments: (self, message))
    }
}
