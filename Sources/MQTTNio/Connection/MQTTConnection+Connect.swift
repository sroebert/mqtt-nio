import Logging
import NIO
import NIOSSL
import Foundation

extension MQTTConnection {
    public static func connect(
        to socketAddress: SocketAddress,
        config: ConnectConfig = .init(),
        logger: Logger = .init(label: "nl.roebert.MQTTNio"),
        on eventLoop: EventLoop
    ) -> EventLoopFuture<MQTTConnection> {
        let bootstrap = ClientBootstrap(group: eventLoop)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        return bootstrap.connect(to: socketAddress).flatMap { channel in
            return channel.pipeline.addHandlers([
                
                // Decoding
                ByteToMessageHandler(MQTTPacketDecoder(logger: logger)),
                MQTTPacketTypeParser(logger: logger),
                
                // Encoding
                MessageToByteHandler(MQTTPacketEncoder(logger: logger)),
                MQTTPacketTypeSerializer(logger: logger),
                
                // Continuous handlers
                MQTTKeepAliveHandler(logger: logger, interval: config.keepAliveInterval),
                MQTTSubscriptionsHandler(logger: logger),
                
                // Outgoing request handlers
                MQTTRequestHandler(logger: logger),
                
                // Error handler
                MQTTErrorHandler(logger: logger)
            ]).flatMap {
                let connection = MQTTConnection(channel: channel, logger: logger)
                let connectRequest = MQTTConnectRequest(config: config)
                return channel.pipeline.send(connectRequest, logger: logger).map {
                    connection
                }.flatMapError { error in
                    connection.close().flatMapThrowing { throw error }
                }
            }
        }
    }
}
    
extension MQTTConnection {
    public struct ConnectConfig {
        public var clientId: String
        public var cleanSession: Bool
        public var credentials: ConnectCredentials?
        public var lastWillMessage: MQTTMessage?
        public var keepAliveInterval: TimeAmount
        
        public var connectTimeoutInterval: TimeAmount
        
        public init(
            clientId: String = "nl.roebert.MQTTNio.\(UUID())",
            cleanSession: Bool = true,
            credentials: ConnectCredentials? = nil,
            lastWillMessage: MQTTMessage? = nil,
            keepAliveInterval: TimeAmount = .seconds(60),
            connectTimeoutInterval: TimeAmount = .seconds(30)) {
            
            self.clientId = clientId
            self.cleanSession = cleanSession
            self.credentials = credentials
            self.lastWillMessage = lastWillMessage
            self.keepAliveInterval = keepAliveInterval
            self.connectTimeoutInterval = connectTimeoutInterval
        }
    }
    
    public struct ConnectCredentials {
        public var username: String
        public var password: ByteBuffer?
        
        public init<Data>(username: String, password: Data)
            where Data: Sequence, Data.Element == UInt8
        {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            buffer.writeBytes(password)
            
            self.init(username: username, password: buffer)
        }
        
        public init(username: String, password: String) {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            buffer.writeString(password)
            
            self.init(username: username, password: buffer)
        }
        
        public init(username: String, password: ByteBuffer? = nil) {
            self.username = username
            self.password = password
        }
    }
}
