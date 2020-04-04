import NIO
import NIOSSL
import Foundation

public struct MQTTConfiguration {
    public var target: Target
    public var tls: TLSConfiguration?
    
    public var eventLoopGroup: EventLoopGroup
    
    public var clientId: String
    public var cleanSession: Bool
    public var credentials: Credentials?
    public var lastWillMessage: MQTTMessage?
    public var keepAliveInterval: TimeAmount
    
    public var connectTimeoutInterval: TimeAmount
    
    public var reconnectMinDelay: TimeAmount
    public var reconnectMaxDelay: TimeAmount
    
    public var publishRetryInterval: TimeAmount
    public var subscriptionTimeoutInterval: TimeAmount
    
    public init(
        target: Target,
        tls: TLSConfiguration? = nil,
        eventLoopGroup: EventLoopGroup,
        clientId: String = "nl.roebert.MQTTNIO.\(UUID())",
        cleanSession: Bool = true,
        credentials: Credentials? = nil,
        lastWillMessage: MQTTMessage? = nil,
        keepAliveInterval: TimeAmount = .seconds(60),
        connectTimeoutInterval: TimeAmount = .seconds(30),
        reconnectMinDelay: TimeAmount = .seconds(1),
        reconnectMaxDelay: TimeAmount = .seconds(120),
        publishRetryInterval: TimeAmount = .seconds(5),
        subscriptionTimeoutInterval: TimeAmount = .seconds(5)) {
        
        self.target = target
        self.tls = tls
        self.eventLoopGroup = eventLoopGroup
        self.clientId = clientId
        self.cleanSession = cleanSession
        self.credentials = credentials
        self.lastWillMessage = lastWillMessage
        self.keepAliveInterval = keepAliveInterval
        self.connectTimeoutInterval = connectTimeoutInterval
        self.reconnectMinDelay = reconnectMinDelay
        self.reconnectMaxDelay = reconnectMaxDelay
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
}
