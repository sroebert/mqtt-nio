import NIO
import Logging

protocol MQTTConnectionStateDelegate: class {
    func mqttConnection(_ connection: MQTTConnection, didChangeFrom oldState: MQTTConnection.State, to newState: MQTTConnection.State)
}

class MQTTConnection {
    
    // MARK: - Vars
    
    let configuration: MQTTConnectionConfiguration
    let logger: Logger
    
    private let stateManager = StateManager()
    
    private(set) var channel: EventLoopFuture<Channel> {
        didSet {
            didChangeChannel()
        }
    }
    
    var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    private(set) var state: State {
        get {
            return stateManager.state
        }
        set {
            stateManager.state = newValue
        }
    }
    
    var stateDelegate: MQTTConnectionStateDelegate? {
        get {
            return stateManager.delegate
        }
        set {
            stateManager.delegate = newValue
        }
    }
    
    private let requestHandler: MQTTRequestHandler
    private let subscriptionsHandler: MQTTSubscriptionsHandler
    
    // MARK: - Init
    
    init(
        configuration: MQTTConnectionConfiguration,
        requestHandler: MQTTRequestHandler,
        subscriptionsHandler: MQTTSubscriptionsHandler,
        logger: Logger
    ) {
        self.configuration = configuration
        self.logger = logger
        
        self.requestHandler = requestHandler
        self.subscriptionsHandler = subscriptionsHandler
        
        channel = MQTTConnection.makeChannel(
            on: configuration.eventLoopGroup.next(),
            configuration: configuration,
            reconnectDelay: configuration.reconnectMinDelay,
            stateManager: stateManager,
            requestHandler: requestHandler,
            subscriptionsHandler: subscriptionsHandler,
            logger: logger
        )
        
        didChangeChannel()
    }
    
    // MARK: - Close
    
    func close() -> EventLoopFuture<Void> {
        if state == .shutdown {
            return channel.flatMap { $0.closeFuture }
        } else {
            stateManager.initiateUserShutdown()
            return channel.flatMap { $0.close() }
        }
    }
    
    // MARK: - Channel Updates
    
    private func didChangeChannel() {
        // Close the channel if the user already initiated shutdown
        guard !stateManager.userHasInitiatedShutdown else {
            channel.whenSuccess { channel in
                channel.close(mode: .all, promise: nil)
            }
            return
        }
        
        channel.flatMap { $0.closeFuture }.whenComplete { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            // Check if we can reconnect
            guard strongSelf.stateManager.canReconnect else {
                return
            }
            
            // Prepare state for reconnect
            strongSelf.state = .transientFailure
            
            // Reconnect
            strongSelf.channel = MQTTConnection.makeChannel(
                on: strongSelf.channel.eventLoop,
                configuration: strongSelf.configuration,
                reconnectDelay: strongSelf.configuration.reconnectMinDelay,
                stateManager: strongSelf.stateManager,
                requestHandler: strongSelf.requestHandler,
                subscriptionsHandler: strongSelf.subscriptionsHandler,
                logger: strongSelf.logger
            )
        }
        channel.whenFailure { [weak self] _ in
            self?.state = .shutdown
        }
    }
    
    // MARK: - Utils
    
    private class func makeChannel(
        on eventLoop: EventLoop,
        configuration: MQTTConnectionConfiguration,
        reconnectDelay: TimeAmount,
        stateManager: StateManager,
        requestHandler: MQTTRequestHandler,
        subscriptionsHandler: MQTTSubscriptionsHandler,
        logger: Logger
    ) -> EventLoopFuture<Channel> {
        
        guard stateManager.state == .idle || stateManager.state == .transientFailure else {
            return configuration.eventLoopGroup.next().makeFailedFuture(MQTTInternalError(message: "Invalid connection state"))
        }
        
        stateManager.state = .connecting
        
        let bootstrap = ClientBootstrap(group: eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .connectTimeout(configuration.connectTimeoutInterval)
        
        let channel = bootstrap.connect(to: configuration.target).flatMap { channel -> EventLoopFuture<Channel> in
            stateManager.state = .ready
            return channel.pipeline.addHandlers([
                // Decoding
                ByteToMessageHandler(MQTTPacketDecoder(logger: logger)),
                MQTTPacketTypeParser(logger: logger),
                
                // Encoding
                MessageToByteHandler(MQTTPacketEncoder(logger: logger)),
                MQTTPacketTypeSerializer(logger: logger),
                
                // Continuous handlers
                MQTTKeepAliveHandler(logger: logger, interval: configuration.keepAliveInterval),
                subscriptionsHandler,
                
                // Outgoing request handlers
                requestHandler,
                
                // Error handler
                MQTTErrorHandler(logger: logger)
            ]).flatMap {
                let connectRequest = MQTTConnectRequest(configuration: configuration)
                return requestHandler.perform(connectRequest, in: channel.eventLoop)
            }.map { channel }
        }
        
        let newReconnectDelay = min(reconnectDelay * 2, configuration.reconnectMaxDelay)
        
        // If we cannot connect, try again in a given interval
        return channel.flatMapError { error in
            stateManager.state = .transientFailure
            return MQTTConnection.scheduleReconnectAttempt(
                in: newReconnectDelay,
                on: channel.eventLoop,
                configuration: configuration,
                stateManager: stateManager,
                requestHandler: requestHandler,
                subscriptionsHandler: subscriptionsHandler,
                logger: logger
            )
        }
    }
    
    private class func scheduleReconnectAttempt(
        in delay: TimeAmount,
        on eventLoop: EventLoop,
        configuration: MQTTConnectionConfiguration,
        stateManager: StateManager,
        requestHandler: MQTTRequestHandler,
        subscriptionsHandler: MQTTSubscriptionsHandler,
        logger: Logger
    ) -> EventLoopFuture<Channel> {
    
        return eventLoop.scheduleTask(in: delay) {
            MQTTConnection.makeChannel(
                on: eventLoop,
                configuration: configuration,
                reconnectDelay: delay,
                stateManager: stateManager,
                requestHandler: requestHandler,
                subscriptionsHandler: subscriptionsHandler,
                logger: logger
            )
        }.futureResult.flatMap { channel in
            channel
        }
    }
}

extension ClientBootstrap {
    fileprivate func connect(to target: MQTTConnectionConfiguration.Target) -> EventLoopFuture<Channel> {
        switch target {
        case .host(let host, port: let port):
            return connect(host: host, port: port)
            
        case .socketAddress(let socketAddress):
            return connect(to: socketAddress)
            
        case .unixDomainSocket(let unixDomainSocketPath):
            return connect(unixDomainSocketPath: unixDomainSocketPath)
        }
    }
}
