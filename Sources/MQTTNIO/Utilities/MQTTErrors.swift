import Foundation

/// Errors that can be received when trying to connect to a broker.
public enum MQTTConnectionError: Error {
    /// The connection was closed while trying to connect.
    case connectionClosed
    
    /// The broker took to long to respond to the connect packet.
    case timeoutWaitingForAcknowledgement
    
    /// The broker send a reason for connection failure.
    case server(ServerReason)
}

extension MQTTConnectionError {
    /// The reason returned from the server, indicating why the connection failed.
    public struct ServerReason {
    
        public enum Code: Equatable {
            /// The connection failed, because of using an unacceptable protocol version.
            case unsupportedProtocolVersion
            
            /// The connection failed, because the provided client identifier was invalid.
            case invalidClientIdentifier
            
            /// The connection failed, because the provided username or password is incorrect.
            case badUsernameOrPassword
            
            /// The connection failed, because the user is not authorized.
            case notAuthorized
            
            /// The connection failed, because the user is banned.
            case banned
            
            /// The connection failed, because the authentication method is invalid.
            case badAuthenticationMethod
            
            /// The connection failed, because the will message topic is not accepted.
            case invalidWillTopic
            
            /// The connection failed, because the will payload format is invalid.
            case invalidWillPayloadFormat
            
            /// The connection failed, because retain is not supported on the broker.
            case willRetainNotSupported
            
            /// The connection failed, because QoS is not supported on the broker.
            case willQoSNotSupported
            
            /// The connection failed, because an implementation or administrative imposed limit has been exceeded.
            case exceededQuota
            
            /// The connection failed, because the server is unavailable.
            case serverUnavailable
            
            /// The connection failed, because the server is busy.
            case serverBusy
            
            /// The connection failed, because the connection rate limit has been exceeded.
            case exceededConnectionRate
            
            /// The client should temporarily use another server.
            case useAnotherServer(String)
            
            /// The client should permanently use another server.
            case serverMoved(String)
            
            /// The connection failed, because the data within the `CONNECT` packet could not be correctly parsed.
            case malformedPacket
            
            /// The connection failed, because the data in the `CONNECT` packet does not conform to the specification.
            case protocolError
            
            /// The connection failed, because the `CONNECT` packet is valid but is not accepted by this server.
            case implementationSpecificError
            
            /// The connection failed, because the `CONNECT` packet exceeded the maximum permissible size.
            case packetTooLarge
            
            /// The connection failed, because the server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
            case unspecifiedError
        }
    
        /// The code indicating the reason for the error.
        public var code: Code
        
        /// An optional message giving more information regarding the reason for failure.
        public var message: String?
    }
    
    var serverReasonCode: ServerReason.Code? {
        switch self {
        case .connectionClosed, .timeoutWaitingForAcknowledgement:
            return nil
            
        case .server(let reason):
            return reason.code
        }
    }
}

/// Errors that can occur while communicating with the broker.
public enum MQTTProtocolError: Error {
    /// The broker rejected the MQTT protocol version of this client.
    case unacceptableVersion
    
    /// A parsing error occurred while communicating with the broker. The string contains a more ellaborate description.
    case parsingError(String)
}

/// Errors that can occur while publishing a message to the broker.
public enum MQTTPublishError: Error {
    /// The client reconnected to the broker and the session was cleared. Because of this, the publish was cancelled.
    case sessionCleared
}

/// Errors that can occur while sending messages to the broker. This is generally a programming error when using this library.
public enum MQTTValueError: Error {
    /// The value being send to the broker is too large for the MQTT message.
    case valueTooLarge(String)
}
