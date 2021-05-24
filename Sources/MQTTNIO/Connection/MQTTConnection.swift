import Foundation
import NIO
import NIOSSL
import NIOHTTP1
import NIOWebSocket
import Logging

protocol MQTTConnectionDelegate: AnyObject {
    func mqttConnection(_ connection: MQTTConnection, didConnectWith response: MQTTConnectResponse)
    func mqttConnection(_ connection: MQTTConnection, didDisconnectWith reason: MQTTDisconnectReason)
    
    func mqttConnection(_ connection: MQTTConnection, caughtError error: Error)
}

final class MQTTConnection: MQTTErrorHandlerDelegate {
    
    // MARK: - Types
    
    private enum ConnectError: Error {
        case userDidInitiateClose
        case invalidWebSocketTarget
    }
    
    private struct ConnectionFlags: OptionSet {
        let rawValue: Int
        
        static let notifiedDelegate = ConnectionFlags(rawValue: 1 << 1)
        static let acceptedByBroker = ConnectionFlags(rawValue: 1 << 2)
        static let triggeredDidConnect = ConnectionFlags(rawValue: 1 << 3)
        
        init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    // MARK: - Vars
    
    let eventLoop: EventLoop
    let configuration: MQTTConfiguration
    let logger: Logger
    
    private let requestHandler: MQTTRequestHandler
    private let subscriptionsHandler: MQTTSubscriptionsHandler
    
    weak var delegate: MQTTConnectionDelegate?
    
    private(set) var firstConnectFuture: EventLoopFuture<Void>!
    private var channelFuture: EventLoopFuture<Channel>!
    
    private var connectionFlags: ConnectionFlags = []
    
    private var didUserInitiateClose: Bool = false
    
    // MARK: - Init
    
    init(
        eventLoop: EventLoop,
        configuration: MQTTConfiguration,
        requestHandler: MQTTRequestHandler,
        subscriptionsHandler: MQTTSubscriptionsHandler,
        logger: Logger
    ) {
        self.eventLoop = eventLoop
        self.configuration = configuration
        self.logger = logger
        
        self.requestHandler = requestHandler
        self.subscriptionsHandler = subscriptionsHandler
        
        channelFuture = connect()
        firstConnectFuture = channelFuture.map { _ in }
    }
    
    // MARK: - Close
    
    func close() -> EventLoopFuture<Void> {
        return eventLoop.flatSubmit {
            self.didUserInitiateClose = true
            return self.channelFuture
        }.flatMap { channel in
            self.shutdown(channel, reason: .userInitiated)
        }.recover { _ in
            // We don't care about channel connection failure as we are closing
        }
    }
    
    // MARK: - Connect
    
    private func connect() -> EventLoopFuture<Channel> {
        return connect(reconnectMode: configuration.reconnectMode)
    }
    
    private func connect(reconnectMode: MQTTConfiguration.ReconnectMode) -> EventLoopFuture<Channel> {
        guard !didUserInitiateClose else {
            logger.debug("Ignoring connect, user initiated close")
            return eventLoop.makeFailedFuture(ConnectError.userDidInitiateClose)
        }
        
        return connectToBroker().flatMap { channel in
            self.logger.debug("Connected to broker", metadata: [
                "target": "\(self.configuration.target)"
            ])
            
            return self.requestConnectionWithBroker(for: channel).flatMapError { error in
                self.logger.debug("Failed Connect request, shutting down channel", metadata: [
                    "error": "\(error)"
                ])
                
                // In case of error, properly shutdown and still throw the same error
                return self.shutdown(channel, reason: .error(error)).flatMapThrowing {
                    throw error
                }
            }.map {
                // On close, notify delegate and setup a new channel
                if reconnectMode.shouldRetry {
                    channel.closeFuture.whenSuccess { result in
                        self.logger.debug("Channel closed, retrying connection")
                        
                        if self.connectionFlags.contains(.notifiedDelegate) {
                            self.connectionFlags.remove(.notifiedDelegate)
                            self.delegate?.mqttConnection(self, didDisconnectWith: .connectionClosed)
                        }
                        
                        self.channelFuture = self.connect()
                    }
                }
                return channel
            }
        }.flatMapError { error in
            self.delegate?.mqttConnection(self, caughtError: error)
            
            self.logger.debug("Failed to connect to broker", metadata: [
                "error": "\(error)"
            ])
            
            guard case .retry(let delay, _) = reconnectMode else {
                return self.eventLoop.makeFailedFuture(error)
            }
            
            self.logger.debug("Scheduling retry to connect to broker", metadata: [
                "delay": "\(delay.nanoseconds / 1_000_000_000)"
            ])
            
            // Reconnect after delay
            return self.eventLoop.scheduleTask(in: delay) {
                self.connect(reconnectMode: reconnectMode.next)
            }.futureResult.flatMap { $0 }
        }
    }
    
    private func connectToBroker() -> EventLoopFuture<Channel> {
        logger.debug("Connecting to broker", metadata: [
            "target": "\(configuration.target)"
        ])
        
        let target = configuration.target
        return ClientBootstrap(group: eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .connectTimeout(configuration.connectionTimeoutInterval)
            .connect(to: target)
            .flatMap { self.initializeTLS(for: $0) }
            .flatMap {
                if let webSocketsConfiguration = self.configuration.webSockets {
                    return self.upgradeWebSocket(for: $0, config: webSocketsConfiguration) {
                        self.addHandlers(to: $0)
                    }
                } else {
                    return self.addHandlers(to: $0)
                }
            }
    }
    
    private func initializeTLS(for channel: Channel) -> EventLoopFuture<Channel> {
        guard let tlsConfiguration = configuration.tls else {
            return eventLoop.makeSucceededFuture(channel)
        }
        
        do {
            let tlsVerificationHandler = TLSVerificationHandler(logger: logger)
            return channel.pipeline.addHandlers([
                try NIOSSLClientHandler(
                    context: try NIOSSLContext(configuration: tlsConfiguration),
                    serverHostname: configuration.target.hostname?.sniServerHostname
                ),
                tlsVerificationHandler
            ]).flatMap {
                tlsVerificationHandler.verify()
            }.map {
                channel
            }
        } catch {
            delegate?.mqttConnection(self, caughtError: error)
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    private func upgradeWebSocket(
        for channel: Channel,
        config: MQTTConfiguration.WebSocketsConfiguration,
        completionHandler: @escaping (Channel) -> EventLoopFuture<Channel>
    ) -> EventLoopFuture<Channel> {
        
        guard case .host(let host, _) = configuration.target else {
            return channel.eventLoop.makeFailedFuture(ConnectError.invalidWebSocketTarget)
        }
        
        let promise = channel.eventLoop.makePromise(of: Channel.self)
        
        let initialRequestHandler = WebSocketInitialRequestHandler(
            logger: logger,
            host: host,
            path: config.path,
            headers: config.headers
        ) { context, error in
            context.fireErrorCaught(error)
            promise.fail(error)
        }
        
        let requestKey = Data(
            (0..<16).map { _ in UInt8.random(in: .min ..< .max) }
        ).base64EncodedString()
        
        let upgrader = NIOWebSocketClientUpgrader(
            requestKey: requestKey
        ) { channel, _ in
            let future = channel.pipeline.addHandler(WebSocketHandler()).flatMap {
                completionHandler(channel)
            }
            future.cascade(to: promise)
            return future.map { _ in }
        }
        
        let config: NIOHTTPClientUpgradeConfiguration = (
            upgraders: [ upgrader ],
            completionHandler: { context in
                channel.pipeline.removeHandler(initialRequestHandler, promise: nil)
            }
        )
        
        return channel.pipeline.addHTTPClientHandlers(withClientUpgrade: config).flatMap {
            channel.pipeline.addHandler(initialRequestHandler)
        }.flatMap {
            promise.futureResult
        }
    }
    
    private func addHandlers(to channel: Channel) -> EventLoopFuture<Channel> {
        eventLoop.assertInEventLoop()
        
        let errorHandler = MQTTErrorHandler(logger: logger)
        errorHandler.delegate = self
        
        return channel.pipeline.addHandlers([
            // Decoding
            ByteToMessageHandler(MQTTPacketDecoder(logger: logger)),
            MQTTPacketTypeParser(
                version: configuration.protocolVersion,
                logger: logger
            ),
            
            // Encoding
            MessageToByteHandler(MQTTPacketEncoder(logger: logger)),
            MQTTPacketTypeSerializer(
                version: configuration.protocolVersion,
                logger: logger
            ),
            
            // Continuous handlers
            MQTTKeepAliveHandler(logger: logger, interval: configuration.keepAliveInterval),
            subscriptionsHandler,
            
            // Outgoing request handlers
            requestHandler,
            
            // Error handler
            errorHandler
        ]).map { channel }
    }
    
    private func requestConnectionWithBroker(for channel: Channel) -> EventLoopFuture<Void> {
        eventLoop.assertInEventLoop()
        
        let request = MQTTConnectRequest(configuration: configuration)
        return requestHandler.perform(request).flatMap { response in
            self.connectionFlags.insert(.notifiedDelegate)
            self.delegate?.mqttConnection(self, didConnectWith: response)
            
            if let error = Self.error(for: response.returnCode) {
                return self.eventLoop.makeFailedFuture(error)
            }
            
            // We established connection
            self.connectionFlags.insert(.acceptedByBroker)
            
            // We don't have to trigger the didConnect if the user already initiated a close
            guard !self.didUserInitiateClose else {
                return self.eventLoop.makeSucceededFuture(())
            }
            
            self.connectionFlags.insert(.triggeredDidConnect)
            return channel.triggerUserOutboundEvent(MQTTConnectionEvent.didConnect(isSessionPresent: response.isSessionPresent))
        }
    }
    
    private static func error(for returnCode: MQTTConnectResponse.ReturnCode) -> Error? {
        switch returnCode {
        case .accepted:
            return nil
        case .unacceptableProtocolVersion:
            return MQTTProtocolError.unacceptableVersion
        case .identifierRejected:
            return MQTTConnectionError.identifierRejected
        case .serverUnavailable:
            return MQTTConnectionError.serverUnavailable
        case .badUsernameOrPassword:
            return MQTTConnectionError.badUsernameOrPassword
        case .notAuthorized:
            return MQTTConnectionError.notAuthorized
        }
    }
    
    // MARK: - Disconnect
    
    private func shutdown(_ channel: Channel, reason: MQTTDisconnectReason) -> EventLoopFuture<Void> {
        eventLoop.assertInEventLoop()
        
        return sendDisconnect(for: channel).flatMap {
            // No we can close the channel
            channel.close().recover { _ in
                // We don't really care if the close fails, just continue
            }.always { _ in
                if self.connectionFlags.contains(.notifiedDelegate) {
                    self.connectionFlags.remove(.notifiedDelegate)
                    self.delegate?.mqttConnection(self, didDisconnectWith: reason)
                }
            }
        }
    }
    
    private func sendDisconnect(for channel: Channel) -> EventLoopFuture<Void> {
        eventLoop.assertInEventLoop()
        
        // Only trigger the `willDisconnect` event if we send a `didConnect` event before.
        let eventFuture: EventLoopFuture<Void>
        if connectionFlags.contains(.triggeredDidConnect) {
            connectionFlags.remove(.triggeredDidConnect)
            eventFuture = channel.triggerUserOutboundEvent(MQTTConnectionEvent.willDisconnect).recover { _ in
                // We don't care if this fails
            }
        } else {
            eventFuture = eventLoop.makeSucceededFuture(())
        }
        
        // Only send disconnect if broker has accepted before
        guard connectionFlags.contains(.acceptedByBroker) else {
            return eventFuture
        }
        
        connectionFlags.remove(.acceptedByBroker)
        return eventFuture.flatMap {
            self.requestHandler.perform(MQTTDisconnectRequest()).recover { _ in
                // We don't care if this fails
            }
        }
    }
    
    // MARK: - MQTTErrorHandlerDelegate
    
    func mttErrorHandler(_ handler: MQTTErrorHandler, caughtError error: Error) {
        delegate?.mqttConnection(self, caughtError: error)
    }
}

extension ClientBootstrap {
    fileprivate func connect(to target: MQTTConfiguration.Target) -> EventLoopFuture<Channel> {
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
    
    fileprivate var sniServerHostname: String? {
        guard isValidSNIServerName else {
            return nil
        }
        return self
    }
}
