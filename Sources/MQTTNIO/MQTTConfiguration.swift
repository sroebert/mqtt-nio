import NIO
import NIOSSL
import Foundation

public struct MQTTConfiguration {
    public var target: Target
    public var tls: TLSConfiguration?
    
    public var clientId: String
    public var cleanSession: Bool
    public var credentials: Credentials?
    public var lastWillMessage: MQTTMessage?
    public var keepAliveInterval: TimeAmount
    
    public var connectionTimeoutInterval: TimeAmount
    
    public var reconnectMode: ReconnectMode
    
    public var connectRequestTimeoutInterval: TimeAmount
    public var publishRetryInterval: TimeAmount
    public var subscriptionTimeoutInterval: TimeAmount
    
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
    public enum Target {
        case host(String, port: Int)
        case unixDomainSocket(String)
        case socketAddress(SocketAddress)
        
        var hostname: String? {
            switch self {
            case .host(let hostname, port: _):
                return hostname
                
            default:
                return nil
            }
        }
    }

    public struct Credentials {
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
    
    public enum ReconnectMode {
        case none
        case retry(minimumDelay: TimeAmount, maximumDelay: TimeAmount)
        
        var shouldRetry: Bool {
            switch self {
            case .none:
                return false
            case .retry:
                return true
            }
        }
        
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
