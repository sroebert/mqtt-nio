import NIO
import NIOSSL
import NIOConcurrencyHelpers
import NIOTransportServices
import Logging
#if canImport(Combine)
import Combine
#endif

/// Client for connecting with an `MQTT` broker.
///
/// This client will be setup using an instance of `MQTTConfiguration`. This configuration
/// can be changed at any point, but most values of this configuration will only be used upon
/// reconnecting with the broker.
///
/// If configured with `.retry` as the reconnect mode, the client will automatically
/// reconnect in case of a connection failure. Any published message will be retried after reconnection.
/// `whenConnected` and `whenDisconnected` can be used to receive callbacks for changes in the connection.
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
    
    /// The `EventLoopGroup` used for the connection with the broker.
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
    
    /// The `MQTTRequestHandler` for the broker connection pipeline.
    private let requestHandler: MQTTRequestHandler
    
    /// The `MQTTSubscriptionsHandler` for the broker connection pipeline.
    private let subscriptionsHandler: MQTTSubscriptionsHandler
    
    /// The list of connect callback entries.
    private let connectCallbacks: CallbackList<MQTTConnectResponse>
    
    /// The list of disconnect callback entries.
    private let disconnectCallback: CallbackList<MQTTDisconnectReason>
    
    /// The list of message callback entries.
    private let messageCallbacks: CallbackList<MQTTMessage>
    
    #if canImport(Combine)
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private lazy var connectSubject: PassthroughSubject<MQTTConnectResponse, Never>! = { nil }()
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private lazy var disconnectSubject: PassthroughSubject<MQTTDisconnectReason, Never>! = { nil }()
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private lazy var messageSubject: PassthroughSubject<MQTTMessage, Never>! = { nil }()
    #endif
    
    private var useNIOTS: Bool {
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            return eventLoopGroup is NIOTSEventLoopGroup
        }
        #endif
        return false
    }
    
    private static func createEventLoopGroup() -> EventLoopGroup {
        #if canImport(Network)
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
            return NIOTSEventLoopGroup()
        }
        #endif
        return MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
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
            eventLoopGroup = Self.createEventLoopGroup()
            shouldShutdownEventLoopGroup = true
            
        case .shared(let eventLoopGroup):
            self.eventLoopGroup = eventLoopGroup
            shouldShutdownEventLoopGroup = false
        }
        self.logger = logger
        
        connectionEventLoop = eventLoopGroup.next()
        
        requestHandler = MQTTRequestHandler(
            eventLoop: connectionEventLoop,
            version: configuration.protocolVersion,
            logger: logger
        )
        subscriptionsHandler = MQTTSubscriptionsHandler(
            acknowledgementHandler: configuration.acknowledgementHandler,
            logger: logger
        )
        
        connectCallbacks = CallbackList()
        disconnectCallback = CallbackList()
        messageCallbacks = CallbackList()
        
        #if canImport(Combine)
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            connectSubject = PassthroughSubject()
            disconnectSubject = PassthroughSubject()
            messageSubject = PassthroughSubject()
        }
        #endif
        
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
            eventLoopGroup.shutdownGracefully { _ in }
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
    /// - Returns: An `EventLoopFuture` with the `MQTTConnectResponse` returned from the broker.
    @discardableResult
    public func connect() -> EventLoopFuture<MQTTConnectResponse> {
        return lock.withLock {
            if let connection = connection {
                return connectionEventLoop.flatSubmit {
                    connection.connectFuture
                }
            }
            
            // Update handler properties to match configuration
            requestHandler.version = _configuration.protocolVersion
            subscriptionsHandler.acknowledgementHandler = _configuration.acknowledgementHandler
            
            let connection = MQTTConnection(
                eventLoop: connectionEventLoop,
                useNIOTS: useNIOTS,
                configuration: _configuration,
                requestHandler: requestHandler,
                subscriptionsHandler: subscriptionsHandler,
                logger: logger
            )
            connection.delegate = self
            self.connection = connection
            
            let connectFuture = connection.connectFuture
            if !_configuration.reconnectMode.shouldRetry {
                // In the case of failure and not retrying,
                // the connection should be cleared, allowing
                // to reconnect again.
                connectFuture.whenFailure { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.lock.withLock {
                        if strongSelf.connection === connection {
                            strongSelf.connection = nil
                        }
                    }
                }
            }
            return connectFuture
        }
    }
    
    /// Disconnects from the broker.
    /// - Parameters:
    ///   - sendWillMessage: If `true` a 5.0 MQTT broker will send the Will message after disconnection. The default value is `false`.
    ///   - sessionExpiry: Optionally a different session expiry can be passed when disconnecting. The default value is `nil`.
    ///   - userProperties: The user properties to send with the disconnect message to a 5.0 MQTT broker.
    /// - Returns: An `EventLoopFuture` for when the disconnection has completed.
    @discardableResult
    public func disconnect(
        sendWillMessage: Bool = false,
        sessionExpiry: MQTTConfiguration.SessionExpiry? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<Void> {
        return lock.withLock {
            guard let connection = connection else {
                return connectionEventLoop.makeSucceededFuture(())
            }
            
            self.connection = nil
            
            let request = MQTTDisconnectReason.UserRequest(
                sendWillMessage: sendWillMessage,
                sessionExpiry: sessionExpiry,
                userProperties: userProperties
            )
            return connection.close(with: request)
        }
    }
    
    /// Disconnects and reconnects to the broker, making sure the updating `configuration` values
    /// are in use.
    /// - Parameters:
    ///   - sendWillMessage: If `true` a 5.0 MQTT broker will send the Will message after disconnection. The default value is `false`.
    ///   - sessionExpiry: Optionally a different session expiry can be passed when disconnecting. The default value is `nil`.
    ///   - userProperties: The user properties to send with the disconnect message to a 5.0 MQTT broker.
    /// - Returns: An `EventLoopFuture` for when the reconnection succeeds or fails.
    @discardableResult
    public func reconnect(
        sendWillMessage: Bool = false,
        sessionExpiry: MQTTConfiguration.SessionExpiry? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<Void> {
        return disconnect(
            sendWillMessage: sendWillMessage,
            sessionExpiry: sessionExpiry,
            userProperties: userProperties
        )
        .flatMap { self.connect() }
        .map { _ in }
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
    ///   - payload: The optional payload of the message. The default is `nil`.
    ///   - topic: The topic for the message.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    /// - Returns: An `EventLoopFuture` for when the publishing has completed.
    @discardableResult
    public func publish(
        _ payload: MQTTPayload = .empty,
        to topic: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: MQTTMessage.Properties = .init()
    ) -> EventLoopFuture<Void> {
        let message = MQTTMessage(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain,
            properties: properties
        )
        return publish(message)
    }
    
    /// Publishes a message to the broker.
    ///
    /// Depending on the QoS level, the client might keep on retrying to publish the message until it succeeds.
    /// - Parameters:
    ///   - payload: The payload of the message in the form of a string.
    ///   - topic: The topic for the message.
    ///   - qos: The QoS level for the message. The default is `.atMostOnce`.
    ///   - retain: Boolean indicating whether to retain the message. The default value is `false`.
    ///   - properties: The message properties to send when publishing to a 5.0 MQTT broker.
    /// - Returns: An `EventLoopFuture` for when the publishing has completed.
    @discardableResult
    public func publish(
        _ payload: String,
        to topic: String,
        qos: MQTTQoS = .atMostOnce,
        retain: Bool = false,
        properties: MQTTMessage.Properties = .init()
    ) -> EventLoopFuture<Void> {
        let message = MQTTMessage(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain,
            properties: properties
        )
        return publish(message)
    }
    
    // MARK: - Subscriptions
    
    /// Subscribes to one or more topics on the broker.
    /// - Parameters:
    ///   - subscriptions: An array of `MQTTSubscription`s indicating what to subscribe to.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An `EventLoopFuture` with an array of `MQTTSubscriptionResult`s indicating the results for each `MQTTSubscription`.
    @discardableResult
    public func subscribe(
        to subscriptions: [MQTTSubscription],
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<MQTTSubscribeResponse> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTSubscribeRequest(
            subscriptions: subscriptions,
            subscriptionIdentifier: identifier,
            userProperties: userProperties,
            timeoutInterval: timeoutInterval
        )
        return requestHandler.perform(request)
    }
    
    /// Subscribes to a topic with a given QoS.
    /// - Parameters:
    ///   - topicFilter: The topic filter to subscribe to.
    ///   - qos: The QoS level with which to subscribe. The default value is `.atMostOnce`.
    ///   - options: Additional subscription options for a 5.0 MQTT broker.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An `EventLoopFuture` with the `MQTTSubscriptionResult` indicating the result of the subscription.
    @discardableResult
    public func subscribe(
        to topicFilter: String,
        qos: MQTTQoS = .atMostOnce,
        options: MQTTSubscription.Options = .init(),
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<MQTTSingleSubscribeResponse> {
        return subscribe(
            to: [.init(topicFilter: topicFilter, qos: qos, options: options)],
            identifier: identifier,
            userProperties: userProperties
        ).map {
            MQTTSingleSubscribeResponse(
                result: $0.results[0],
                userProperties: $0.userProperties,
                reasonString: $0.reasonString
            )
        }
    }
    
    /// Subscribes to one or more topics with a given QoS level.
    /// - Parameters:
    ///   - topicFilters: The topic filters to subscribe to.
    ///   - qos: The QoS level with which to subscribe. The default value is `.atMostOnce`.
    ///   - options: Additional subscription options for a 5.0 MQTT broker.
    ///   - identifier: Optional identifier which will be send to broker and will be set on messages received for this subscription. This only works with 5.0 MQTT brokers.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An `EventLoopFuture` with the `MQTTSubscriptionResult` indicating the result of the subscription.
    @discardableResult
    public func subscribe(
        to topicFilters: [String],
        qos: MQTTQoS = .atMostOnce,
        options: MQTTSubscription.Options = .init(),
        identifier: Int? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<MQTTSubscribeResponse> {
        return subscribe(
            to: topicFilters.map { .init(topicFilter: $0, qos: qos, options: options) },
            identifier: identifier,
            userProperties: userProperties
        )
    }
    
    /// Unsubscribe from one or more topics.
    /// - Parameters:
    ///   - topicFilters: The topic filters to unsubscribe from.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An `EventLoopFuture` with the `MQTTUnsubscribeResponse` indicating the result of unsubscribing.
    @discardableResult
    func unsubscribe(
        from topicFilters: [String],
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<MQTTUnsubscribeResponse> {
        let timeoutInterval = configuration.subscriptionTimeoutInterval
        let request = MQTTUnsubscribeRequest(
            topicFilters: topicFilters,
            userProperties: userProperties,
            timeoutInterval: timeoutInterval
        )
        return requestHandler.perform(request)
    }
    
    /// Unsubscribe from a topic.
    /// - Parameters:
    ///   - topicFilter: The topic filter to unsubscribe from.
    ///   - userProperties: Additional user properties to send when subscribing. This only works with 5.0 MQTT brokers.
    /// - Returns: An `EventLoopFuture` with the `MQTTUnsubscribeResponse` indicating the result of unsubscribing.
    @discardableResult
    public func unsubscribe(
        from topicFilter: String,
        userProperties: [MQTTUserProperty] = []
    ) -> EventLoopFuture<MQTTSingleUnsubscribeResponse> {
        return unsubscribe(
            from: [topicFilter],
            userProperties: userProperties
        ).map {
            MQTTSingleUnsubscribeResponse(
                result: $0.results[0],
                userProperties: $0.userProperties,
                reasonString: $0.reasonString
            )
        }
    }
    
    // MARK: - Re-authenticate
    
    /// Performs re-authentication with the broker.
    ///
    /// When performing re-authentication, the same authentication method should be used that was
    /// used for connecting with the broker in the first place.
    /// - Parameters:
    ///   - handler: The authentication handler to use.
    ///   - timeout: The time to wait for an authentication response from the broker. The default value is `5` seconds.
    /// - Returns: An `EventLoopFuture` for when the re-authentication has completed.
    public func reAuthenticate(
        using handler: MQTTAuthenticationHandler,
        timeout: TimeAmount = .seconds(5)
    ) -> EventLoopFuture<Void> {
        let request = MQTTReAuthenticateRequest(
            authenticationHandler: handler,
            timeoutInterval: timeout
        )
        return requestHandler.perform(request)
    }
    
    // MARK: - Callbacks
    
    /// Adds an observer callback which will be called when the client has connected to a broker.
    /// - Parameter callback: The observer callback to add which will be called with the connect response when connected to a broker.
    /// - Returns: An `MQTTCancellable` which can be used to cancel the observer callback.
    @discardableResult
    public func whenConnected(_ callback: @escaping (_ response: MQTTConnectResponse) -> Void) -> MQTTCancellable {
        return connectCallbacks.append(callback)
    }
    
    /// Adds an observer callback which will be called when the client has disconnected from a broker.
    /// - Parameter callback: The observer callback to add which will be called when disconnect with the reason for disconnection.
    /// - Returns: An `MQTTCancellable` which can be used to cancel the observer callback.
    @discardableResult
    public func whenDisconnected(_ callback: @escaping (_ reason: MQTTDisconnectReason) -> Void) -> MQTTCancellable {
        return disconnectCallback.append(callback)
    }
    
    /// Adds an observer callback which will be called when the client has received an `MQTTMessage`.
    /// - Parameter callback: The observer callback to add which will be called with the received message.
    /// - Returns: An `MQTTCancellable` which can be used to cancel the observer callback.
    @discardableResult
    public func whenMessage(_ callback: @escaping (_ message: MQTTMessage) -> Void) -> MQTTCancellable {
        return messageCallbacks.append(callback)
    }
    
    // MARK: - Publishers
    
    #if canImport(Combine)
    
    /// Publisher receiving messages when this client is connected to a broker.
    ///
    /// This is only available on platforms where `Combine` is available.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public var connectPublisher: AnyPublisher<MQTTConnectResponse, Never> {
        return connectSubject.eraseToAnyPublisher()
    }
    
    /// Publisher receiving messages when this client disconnects from a broker.
    ///
    /// This is only available on platforms where `Combine` is available.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public var disconnectPublisher: AnyPublisher<MQTTDisconnectReason, Never> {
        return disconnectSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for receiving MQTT messages.
    ///
    /// This is only available on platforms where `Combine` is available.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public var messagePublisher: AnyPublisher<MQTTMessage, Never> {
        return messageSubject.eraseToAnyPublisher()
    }
    
    /// Returns a publisher for receiving MQTT messages to a specific topic.
    /// - Parameter topic: The topic to receive messages for.
    ///
    /// This is only available on platforms where `Combine` is available.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func messagePublisher(forTopic topic: String) -> AnyPublisher<MQTTMessage, Never> {
        return messageSubject
            .filter { $0.topic == topic }
            .eraseToAnyPublisher()
    }
    
    #endif
    
    // MARK: - MQTTConnectionDelegate
    
    func mqttConnection(_ connection: MQTTConnection, didConnectWith response: MQTTConnectResponse) {
        lock.withLockVoid {
            _isConnected = true
        }
        
        connectCallbacks.emit(arguments: response)
        
        #if canImport(Combine)
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            connectSubject.send(response)
        }
        #endif
    }
    
    func mqttConnection(_ connection: MQTTConnection, didDisconnectWith reason: MQTTDisconnectReason) {
        lock.withLockVoid {
            _isConnected = false
        }
        
        disconnectCallback.emit(arguments: reason)
        
        #if canImport(Combine)
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            disconnectSubject.send(reason)
        }
        #endif
    }
    
    // MARK: - MQTTSubscriptionsHandlerDelegate
    
    func mqttSubscriptionsHandler(_ handler: MQTTSubscriptionsHandler, didReceiveMessage message: MQTTMessage) {
        messageCallbacks.emit(arguments: message)
        
        #if canImport(Combine)
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            messageSubject.send(message)
        }
        #endif
    }
}
