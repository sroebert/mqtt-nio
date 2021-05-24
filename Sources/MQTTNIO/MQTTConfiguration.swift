import NIO
import NIOSSL
import Foundation

/// Configuration for the `MQTTClient`.
public struct MQTTConfiguration {
    /// The target for the broker the client should connect to.
    public var target: Target
    
    /// The TLS configuration for the connection with the broker. If `nil`, the connection is insecure.
    public var tls: TLSConfiguration?
    
    /// The configuration which should be set when using web sockets to connect.
    public var webSockets: WebSocketsConfiguration?
    
    /// The MQTT protocol version to use when connecting to the broker.
    public var protocolVersion: MQTTProtocolVersion
    
    /// The client identifier to use for the connection with the broker. This should be unique for each client connected to the broker.
    public var clientId: String
    
    /// Boolean, indicating whether the session for the client should be cleaned by the broker. If set to `false`, the broker will
    /// try to keep the session and the subscribed topics for the client. When connected, a boolean is returned from the broker
    /// indicating whether it has an active session for the client. The behavior for this setting is different between protocol version 3.1.1 and 5,
    /// this is explained in detail in the documentation for the different MQTT version.
    public var clean: Bool
    
    /// The optional credentials used to connect to the broker.
    public var credentials: Credentials?
    
    /// The optional `MQTTMessage` the broker should send under certain conditions if the client would disconnect.
    public var willMessage: MQTTWillMessage?
    
    /// The time interval in which a message must be send to the broker to keep the connection alive.
    public var keepAliveInterval: TimeAmount
    
    /// The connection properties to send when connecting with a 5.0 MQTT broker.
    public var connectProperties: ConnectProperties
    
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
    ///   - webSockets: The configuration which should be set when using web sockets to connect. The default value is `nil`, indicating that web sockets should not be used.
    ///   - protocolVersion: The MQTT protocol version to use when connecting to the broker. The default value is 3.1.1.
    ///   - clientId: The client identifier to use for the connection with the broker. The default value is `nl.roebert.MQTTNIO.` followed by a `UUID`.
    ///   - clean: Boolean, indicating whether the session for the client should be cleaned by the broker. The default value is `true`.
    ///   - credentials: The credentials used to connect to the broker. The default value is `nil`.
    ///   - willMessage: The optional `MQTTMessage` the broker should send under certain conditions if the client would disconnect. The default value is `nil`.
    ///   - keepAliveInterval: The time interval in which a message must be send to the broker to keep the connection alive. The default value is `60` seconds.
    ///   - connectProperties: The connection properties to send when connecting with a 5.0 MQTT broker.
    ///   - connectionTimeoutInterval: The interval after which connection with the broker will fail. The default value is `30` seconds.
    ///   - reconnectMode: The mode for reconnection that will be used if the client is disconnected from the server. The default value is `retry` with a minimum of `1` second and maximum of `120` seconds.
    ///   - connectRequestTimeoutInterval: The time to wait for the server to respond to a connect message from the client. The default value is `5` seconds.
    ///   - publishRetryInterval: The time to wait before an unacknowledged publish message is retried. The default value is `5` seconds.
    ///   - subscriptionTimeoutInterval: The time to wait for an acknowledgement for subscribing or unsubscribing. The default value is `5` seconds.
    public init(
        target: Target,
        tls: TLSConfiguration? = nil,
        webSockets: WebSocketsConfiguration? = nil,
        protocolVersion: MQTTProtocolVersion = .version3_1_1,
        clientId: String = "nl.roebert.MQTTNIO.\(UUID())",
        clean: Bool = true,
        credentials: Credentials? = nil,
        willMessage: MQTTWillMessage? = nil,
        keepAliveInterval: TimeAmount = .seconds(60),
        connectProperties: ConnectProperties = ConnectProperties(),
        connectionTimeoutInterval: TimeAmount = .seconds(30),
        reconnectMode: ReconnectMode = .retry(minimumDelay: .seconds(1), maximumDelay: .seconds(120)),
        connectRequestTimeoutInterval: TimeAmount = .seconds(5),
        publishRetryInterval: TimeAmount = .seconds(5),
        subscriptionTimeoutInterval: TimeAmount = .seconds(5)
    ) {
        self.target = target
        self.tls = tls
        self.webSockets = webSockets
        self.protocolVersion = protocolVersion
        self.clientId = clientId
        self.clean = clean
        self.credentials = credentials
        self.willMessage = willMessage
        self.keepAliveInterval = keepAliveInterval
        self.connectProperties = connectProperties
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
            case .host(let hostname, _):
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
            self.init(username: username, password: password.byteBuffer)
        }
        
        /// Creates a `Credentials` struct.
        /// - Parameters:
        ///   - username: The username for the credentials.
        ///   - password: The password for the credentials as a string.
        public init(username: String, password: String) {
            self.init(username: username, password: password.byteBuffer)
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
    
    /// The configuration to setup a connection using websockets.
    public struct WebSocketsConfiguration {
        
        /// The web socket path to use.
        public var path: String
        
        /// Extra headers to send with the web socket upgrade request.
        public var headers: [String: String]
        
        /// Creates a `WebSocketsConfiguration` struct.
        /// - Parameters:
        ///   - path: The web socket path to use. The default value is `"/mqtt"`.
        ///   - headers: The extra headers to send when making the web socket upgrade request. The default value is an empty dictionary.
        public init(
            path: String = "/mqtt",
            headers: [String: String] = [:]
        ) {
            self.path = path
            self.headers = headers
        }
        
        /// The basic configuration for using web sockets.
        public static let enabled: Self = .init()
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
    
    /// For 5.0 MQTT brokers indicates when the session of the client should expire.
    public enum SessionExpiry {
        /// Expire when the connection is closed.
        case atClose
        /// Expires after a certain interval.
        case afterInterval(TimeAmount)
        /// Never expires.
        case never
    }
    
    /// Properties used when connecting with a 5.0 MQTT broker.
    public struct ConnectProperties {
        
        /// Indicates when the session of the client should expire.
        public var sessionExpiry: SessionExpiry
        
        /// The receive maximum, indicating the maximum number of QoS > 0 packets that can be received concurrently.
        public var receiveMaximum: Int?
        
        /// The maximum allowed size of packets to receive.
        public var maximumPacketSize: Int?
        
        /// The maximum allowed value to receive from the server for a topic alias.
        public var topicAliasMaximum: Int
        
        /// Indicates whether the server should provide response information when connecting.
        public var requestResponseInformation: Bool
        
        /// Indicates whether the server should provide a reason string and user properties in case of failures.
        public var requestProblemInformation: Bool
        
        /// Additional user properties to send when connecting with the broker.
        public var userProperties: [MQTTUserProperty]
        
        /// The authentication handler to use for enhanced authentication.
        public var authenticationHandler: MQTTAuthenticationHandler?
        
        /// Creates an `ConnectProperties`.
        /// - Parameters:
        ///   - sessionExpiry: Indicates when the session of the client should expire.
        ///   - receiveMaximum: The receive maximum, indicating the maximum number of QoS > 0 packets that can be received concurrently. The default value is `nil`, indicating the server should use the default value.
        ///   - maximumPacketSize: The maximum allowed size of packets to receive. The default value is `nil`, indicating that there is no maximum.
        ///   - topicAliasMaximum: The maximum allowed value to receive from the server for a topic alias. The default value is `0`, indicating that no topic aliases are allowed.
        ///   - requestResponseInformation: Indicates whether the server should provide response information when connecting. The default value is `false`.
        ///   - requestProblemInformation: Indicates whether the server should provide a reason string and user properties in case of failures. The default value is `true`.
        ///   - userProperties: Additional user properties to send when connecting with the broker. The default value is an empty array.
        ///   - authenticationHandler: The authentication handler to use for enhanced authentication.. The default value is `nil`, indicating that there is no enhanced authentication.
        public init(
            sessionExpiry: SessionExpiry = .atClose,
            receiveMaximum: Int? = nil,
            maximumPacketSize: Int? = nil,
            topicAliasMaximum: Int = 0,
            requestResponseInformation: Bool = false,
            requestProblemInformation: Bool = true,
            userProperties: [MQTTUserProperty] = [],
            authenticationHandler: MQTTAuthenticationHandler? = nil
        ) {
            self.sessionExpiry = sessionExpiry
            self.receiveMaximum = receiveMaximum
            self.maximumPacketSize = maximumPacketSize
            self.topicAliasMaximum = topicAliasMaximum
            self.requestResponseInformation = requestResponseInformation
            self.requestProblemInformation = requestProblemInformation
            self.userProperties = userProperties
            self.authenticationHandler = authenticationHandler
        }
    }
}
