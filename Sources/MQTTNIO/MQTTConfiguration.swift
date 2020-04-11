import NIO
import NIOSSL
import Foundation

/// Configuration for the `MQTTClient`.
public struct MQTTConfiguration {
    /// The target for the broker the client should connect to.
    public var target: Target
    
    /// The TLS configuration for the connection with the broker. If `nil`, the connection is insecure.
    public var tls: TLSConfiguration?
    
    /// The client identifier to use for the connection with the broker. This should be unique for each client connected to the broker.
    public var clientId: String
    
    /// Boolean, indicating whether the session for the client should be cleaned by the broker. If set to `false`, the broker will
    /// try to keep the session and the subscribed topics for the client. When connected, a boolean is returned from the broker
    /// indicating whether it has an active session for the client.
    public var cleanSession: Bool
    
    /// The optional credentials used to connect to the broker.
    public var credentials: Credentials?
    
    /// The optional `MQTTMessage` the broker should send if the client would disconnect abnormally..
    public var lastWillMessage: MQTTMessage?
    
    /// The time interval in which a message must be send to the broker to keep the connection alive.
    public var keepAliveInterval: TimeAmount
    
    /// The interval after which connection with the broker will fail.
    public var connectionTimeoutInterval: TimeAmount
    
    /// The mode for reconnection that will be used if the client is disconnected from the server.
    public var reconnectMode: ReconnectMode
    
    /// The time to wait for the server to respond to a connect message from the client.
    public var connectRequestTimeoutInterval: TimeAmount
    
    /// The time to wait before an unacknowledged publish message is retried.
    public var publishRetryInterval: TimeAmount
    
    /// The time to wait for an acknowledgement for subscribing or unsubscribing.
    public var subscriptionTimeoutInterval: TimeAmount
    
    /// Creates an `MQTTConfiguration`.
    /// - Parameters:
    ///   - target: The target for the broker the client should connect to.
    ///   - tls: The TLS configuration for the connection with the broker. The default value is `nil`.
    ///   - clientId: The client identifier to use for the connection with the broker. The default value is `nl.roebert.MQTTNIO.` followed by a `UUID`.
    ///   - cleanSession: Boolean, indicating whether the session for the client should be cleaned by the broker. The default value is `true`.
    ///   - credentials: The credentials used to connect to the broker. The default value is `nil`.
    ///   - lastWillMessage: The  `MQTTMessage` the broker should send if the client would disconnect abnormally. The default value is `nil`.
    ///   - keepAliveInterval: The time interval in which a message must be send to the broker to keep the connection alive. The default value is `60` seconds.
    ///   - connectionTimeoutInterval: The interval after which connection with the broker will fail. The default value is `30` seconds.
    ///   - reconnectMode: The mode for reconnection that will be used if the client is disconnected from the server. The default value is `retry` with a minimum of `1` second and maximum of `120` seconds.
    ///   - connectRequestTimeoutInterval: The time to wait for the server to respond to a connect message from the client. The default value is `5` seconds.
    ///   - publishRetryInterval: The time to wait before an unacknowledged publish message is retried. The default value is `5` seconds.
    ///   - subscriptionTimeoutInterval: The time to wait for an acknowledgement for subscribing or unsubscribing. The default value is `5` seconds.
    public init(
        target: Target,
        tls: TLSConfiguration? = nil,
        clientId: String = "nl.roebert.MQTTNIO.\(UUID())",
        cleanSession: Bool = true,
        credentials: Credentials? = nil,
        lastWillMessage: MQTTMessage? = nil,
        keepAliveInterval: TimeAmount = .seconds(60),
        connectionTimeoutInterval: TimeAmount = .seconds(30),
        reconnectMode: ReconnectMode = .retry(minimumDelay: .seconds(1), maximumDelay: .seconds(120)),
        connectRequestTimeoutInterval: TimeAmount = .seconds(5),
        publishRetryInterval: TimeAmount = .seconds(5),
        subscriptionTimeoutInterval: TimeAmount = .seconds(5)) {
        
        self.target = target
        self.tls = tls
        self.clientId = clientId
        self.cleanSession = cleanSession
        self.credentials = credentials
        self.lastWillMessage = lastWillMessage
        self.keepAliveInterval = keepAliveInterval
        self.connectionTimeoutInterval = connectionTimeoutInterval
        self.reconnectMode = reconnectMode
        self.connectRequestTimeoutInterval = connectRequestTimeoutInterval
        self.publishRetryInterval = publishRetryInterval
        self.subscriptionTimeoutInterval = subscriptionTimeoutInterval
    }
}

extension MQTTConfiguration {
    
    /// The target for the `MQTTClient` to connect to.
    public enum Target {
        /// Target indicated by a hostname and port number.
        case host(String, port: Int)
        
        /// Target indicated by a unix domain socket name.
        case unixDomainSocket(String)
        
        /// Target indicated by a socket address.
        case socketAddress(SocketAddress)
        
        /// The optional hostname for the target. This is used for the `TLS` configuration.
        var hostname: String? {
            switch self {
            case .host(let hostname, port: _):
                return hostname
                
            default:
                return nil
            }
        }
    }

    /// The credentials for connection with a broker.
    public struct Credentials {
        
        /// The username to connect with.
        public var username: String
        
        // The password to connect with as bytes.
        public var password: ByteBuffer?
        
        /// Creates a `Credentials` struct.
        /// - Parameters:
        ///   - username: The username for the credentials.
        ///   - password: The password for the credentials as a sequence of bytes.
        public init<Data>(username: String, password: Data)
            where Data: Sequence, Data.Element == UInt8
        {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            buffer.writeBytes(password)
            
            self.init(username: username, password: buffer)
        }
        
        /// Creates a `Credentials` struct.
        /// - Parameters:
        ///   - username: The username for the credentials.
        ///   - password: The password for the credentials as a string.
        public init(username: String, password: String) {
            var buffer = ByteBufferAllocator().buffer(capacity: 0)
            buffer.writeString(password)
            
            self.init(username: username, password: buffer)
        }
        
        /// Creates a `Credentials` struct.
        /// - Parameters:
        ///   - username: The username for the credentials.
        ///   - password: The password for the credentials as a `ByteBuffer`. The default value is `nil`.
        public init(username: String, password: ByteBuffer? = nil) {
            self.username = username
            self.password = password
        }
    }
    
    /// The reconnect mode for an `MQTTClient` to use when it gets disconnected from the broker.
    public enum ReconnectMode {
        /// The client will not automatically reconnect.
        case none
        
        /// The client will try to reconnect.
        ///
        /// When retrying to connect, the client will first try to reconnect after a delay of `minimumDelay`.
        /// If the reconnection does not succeed, it will retry again by doubling the delay to retry, with a
        /// maximum delay of `maximumDelay`.
        ///
        /// - Parameters:
        ///   - minimumDelay: The minimum delay between connection retries.
        ///   - maximumDelay: The maximum delay between connection retries.
        case retry(minimumDelay: TimeAmount, maximumDelay: TimeAmount)
        
        /// Indicates whether the client should retry to connect with this mode.
        var shouldRetry: Bool {
            switch self {
            case .none:
                return false
            case .retry:
                return true
            }
        }
        
        /// Returns the next `ReconnectMode`, by doubling the `minimumDelay`, up till the `maximumDelay`.
        var next: ReconnectMode {
            switch self {
            case .none:
                return .none
                
            case .retry(let minimumDelay, let maximumDelay):
                let newDelay = min(minimumDelay * 2, maximumDelay)
                return .retry(minimumDelay: newDelay, maximumDelay: maximumDelay)
            }
        }
    }
}
