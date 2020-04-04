import NIO
import NIOSSL
import Logging

protocol MQTTConnectionStateDelegate: class {
    func mqttConnection(_ connection: MQTTConnection, didChangeFrom oldState: MQTTConnection.State, to newState: MQTTConnection.State)
}

class MQTTConnection {
    
    // MARK: - Vars
    
    let configuration: MQTTConnectionConfiguration
    let logger: Logger
    
    private let stateManager: StateManager
    
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
        self.stateManager = StateManager(logger: logger)
        
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
        stateManager.initiateUserShutdown()
        channel.whenSuccess { $0.close(mode: .all, promise: nil) }
        
        let eventLoop = self.eventLoop
        return channel.map { channel -> Channel? in
            return channel
        }.flatMapErrorThrowing { _ in
            return nil
        }.flatMap { optionalChannel in
            guard let channel = optionalChannel else {
                return eventLoop.makeSucceededFuture(())
            }
            return channel.closeFuture
        }
    }
    
    // MARK: - Channel Updates
    
    private func didChangeChannel() {
        // Close the channel if the user already initiated shutdown
        guard !stateManager.userHasInitiatedShutdown else {
            channel.whenSuccess { [weak self] channel in
                self?.logger.debug("Closing channel, user initiated shutdown while connecting")
                channel.close(mode: .all, promise: nil)
            }
            return
        }
        
        channel.flatMap { $0.closeFuture }.whenComplete { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            
            switch result {
            case .success:
                strongSelf.logger.debug("Client connection successfully shutdown")
            case .failure(let error):
                strongSelf.logger.warning("Client connection shutdown failed", metadata: [
                    "error": "\(error)"
                ])
            }
            
            // Check if we can reconnect
            guard strongSelf.stateManager.canReconnect else {
                strongSelf.logger.debug("Client not reconnecting, state does not allow it", metadata: [
                    "state": "\(strongSelf.state)"
                ])
                return
            }
            
            // Prepare state for reconnect
            strongSelf.state = .transientFailure
            
            // Reconnect
            strongSelf.logger.debug("Client creating a new channel")
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
        
        logger.debug("Client starting connection", metadata: [
            "target": "\(configuration.target)",
        ])
        
        stateManager.state = .connecting
        
        let bootstrap = ClientBootstrap(group: eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .connectTimeout(configuration.connectTimeoutInterval)
        
        let channel = bootstrap.connect(to: configuration.target).flatMap { channel -> EventLoopFuture<Channel> in
            stateManager.state = .ready
            return configureChannel(
                channel,
                configuration: configuration,
                requestHandler: requestHandler,
                subscriptionsHandler: subscriptionsHandler,
                logger: logger
            ).flatMap {
                logger.debug("Client connected, sending connect request")
                
                let connectRequest = MQTTConnectRequest(configuration: configuration)
                return requestHandler.perform(connectRequest, in: channel.eventLoop)
            }.flatMap {
                channel.triggerUserOutboundEvent(MQTTConnectionEvent.didConnect)
            }.map { channel }
        }
        
        let newReconnectDelay = min(reconnectDelay * 2, configuration.reconnectMaxDelay)
        
        // If we cannot connect, try again in a given interval
        return channel.flatMapError { error in
            logger.debug("Client connection failed", metadata: [
                "error": "\(error)",
            ])
            
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
    
    private class func configureChannel(
        _ channel: Channel,
        configuration: MQTTConnectionConfiguration,
        requestHandler: MQTTRequestHandler,
        subscriptionsHandler: MQTTSubscriptionsHandler,
        logger: Logger) -> EventLoopFuture<Void> {
        
        return configureTLS(
            with: configuration.tls,
            serverHostname: configuration.target.hostname?.sniServerHostname,
            in: channel,
            logger: logger
        ).flatMap {
            channel.pipeline.addHandlers([
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
            ])
        }
    }
    
    private class func configureTLS(
        with configuration: TLSConfiguration?,
        serverHostname: String?,
        in channel: Channel,
        logger: Logger
    ) -> EventLoopFuture<Void> {
        guard let configuration = configuration else {
            return channel.eventLoop.makeSucceededFuture(())
        }
        
        do {
            let tlsVerificationHandler = TLSVerificationHandler(logger: logger)
            return channel.pipeline.addHandlers([
                try NIOSSLClientHandler(
                    context: try NIOSSLContext(configuration: configuration),
                    serverHostname: serverHostname
                ),
                tlsVerificationHandler
            ]).flatMap {
                tlsVerificationHandler.verify()
            }
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
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
        
        logger.debug("Client scheduling reconnection", metadata: [
            "delay": .stringConvertible(delay.nanoseconds / 1_000_000_000),
        ])
    
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

extension String {
    private var isIPAddress: Bool {
        var ipv4Addr = in_addr()
        var ipv6Addr = in6_addr()

        return self.withCString { ptr in
            return inet_pton(AF_INET, ptr, &ipv4Addr) == 1 ||
                   inet_pton(AF_INET6, ptr, &ipv6Addr) == 1
        }
    }

    private var isValidSNIServerName: Bool {
        guard !isIPAddress else {
            return false
        }

        guard !self.utf8.contains(0) else {
            return false
        }

        guard (1 ... 255).contains(self.utf8.count) else {
            return false
        }
        
        return true
    }
    
    var sniServerHostname: String? {
        guard isValidSNIServerName else {
            return nil
        }
        return self
    }
}
