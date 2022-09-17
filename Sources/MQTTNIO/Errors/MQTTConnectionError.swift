/// Errors that can be received when trying to connect to a broker.
public enum MQTTConnectionError: Error, MQTTSendable {
    /// The provided TLS configuration is invalid for the provided event loop group.
    case invalidTLSConfiguration
    
    /// The connection was closed while performing a request.
    case connectionClosed
    
    /// The broker took to long to respond to a packet.
    case timeoutWaitingForAcknowledgement
    
    /// The broker send a reason for connection failure.
    case server(ServerReason)
}

extension MQTTConnectionError {
    /// The reason returned from the server, indicating why the connection failed.
    public struct ServerReason: MQTTSendable {
    
        public enum Code: Equatable, MQTTSendable {
            /// The server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
            case unspecifiedError
            
            /// A malformed packet was sent to the broker.
            case malformedPacket
            
            /// Data that was sent to the broker does not conform to the specification.
            case protocolError
            
            /// The data that was send is valid but is not accepted by the server.
            case implementationSpecificError
            
            /// An unacceptable protocol version was used.
            case unsupportedProtocolVersion
            
            /// The provided client identifier is invalid.
            case clientIdentifierNotValid
            
            /// The provided username or password is incorrect.
            case badUsernameOrPassword
            
            /// The user is not authorized to perform this operation.
            case notAuthorized
            
            /// The server is unavailable.
            case serverUnavailable
            
            /// The server is busy.
            case serverBusy
            
            /// The user is banned.
            case banned
            
            /// The authentication method is invalid.
            case badAuthenticationMethod
            
            /// The Will message topic is not accepted.
            case topicNameInvalid
            
            /// The packet that was sent exceeded the maximum permissible size.
            case packetTooLarge
            
            /// An implementation or administrative imposed limit has been exceeded.
            case quotaExceeded
            
            /// The Will message payload format is invalid.
            case payloadFormatInvalid
            
            /// Retain is not supported on the broker and the Will message had retain set to `true`.
            case retainNotSupported
            
            /// The QoS for the Will message  is not supported on the broker.
            case qosNotSupported
            
            /// The client should temporarily use another server.
            case useAnotherServer(String?)
            
            /// The client should permanently use another server.
            case serverMoved(String?)
            
            /// The connection rate limit has been exceeded.
            case connectionRateExceeded
        }
    
        /// The code indicating the reason for the error.
        public var code: Code
        
        /// An optional message giving more information regarding the reason for failure.
        public var message: String?
    }
    
    var serverReasonCode: ServerReason.Code? {
        switch self {
        case .invalidTLSConfiguration, .connectionClosed, .timeoutWaitingForAcknowledgement:
            return nil
            
        case .server(let reason):
            return reason.code
        }
    }
}
