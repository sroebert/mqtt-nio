/// The reason the `MQTTClient` was disconnected.
public enum MQTTDisconnectReason {
    /// The user requested to close the connection.
    case userInitiated(UserRequest)
    
    /// The connection was closed without a specific reason. This could be because of an error in the connection (e.g. no Internet). Optionally the error that triggered the close is attached.
    case connectionClosed(Error? = nil)
    
    /// The client disconnected because of protocol error.
    case client(MQTTProtocolError)
    
    /// The server requested to close the connection, optionally with a specific reason.
    case server(ServerReason?)
}

extension MQTTDisconnectReason {
    /// When disconnecting use the `disconnect` function from the `MQTTClient`, this structure holds the data passed with the disconnect request.
    public struct UserRequest {
        /// If `true` a 5.0 MQTT broker will send the Will message after disconnection.
        public var sendWillMessage: Bool
        
        /// Optionally a different session expiry can be passed when disconnecting.
        public var sessionExpiry: MQTTConfiguration.SessionExpiry?
        
        /// The user properties to send with the disconnect message to a 5.0 MQTT broker.
        public var userProperties: [MQTTUserProperty]
    }
    
    public struct ServerReason: Equatable {
        
        public enum Code: Equatable {
            /// The server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
            case unspecifiedError
            
            /// The received packet does not conform to this specification.
            case malformedPacket
            
            /// An unexpected or out of order packet was received.
            case protocolError
            
            /// The data that was send is valid but is not accepted by the server.
            case implementationSpecificError
            
            /// The user is not authorized to perform this operation.
            case notAuthorized
            
            /// The server is busy.
            case serverBusy
            
            /// The server is shutting down.
            case serverShuttingDown
            
            /// There was a timeout on the keep alive response.
            case keepAliveTimeout
            
            /// Another connection using the same client ID has connected causing this connection to be closed.
            case sessionTakenOver
            
            /// The topic filter was not accepted by the server.
            case topicFilterInvalid
            
            /// The topic name was not accepted by the server.
            case topicNameInvalid
            
            /// The server has received more than Receive Maximum publication.
            case receiveMaximumExceeded
            
            /// The topic alias was greater than the allowed maximum.
            case topicAliasInvalid
            
            /// The packet that was sent exceeded the maximum permissible size.
            case packetTooLarge
            
            /// The received data rate is too high.
            case messageRateTooHigh
            
            /// An implementation or administrative imposed limit has been exceeded.
            case quotaExceeded
            
            /// The connection is closed due to an administrative action.
            case administrativeAction
            
            /// The message payload format is invalid.
            case payloadFormatInvalid
            
            /// Retain is not supported on the broker and the there was a message send with retain set to `true`.
            case retainNotSupported
            
            /// The QoS for a send message is not supported on the broker.
            case qosNotSupported
            
            /// The client should temporarily use another server.
            case useAnotherServer(String?)
            
            /// The client should permanently use another server.
            case serverMoved(String?)
            
            /// The server does not support shared subscriptions for this client.
            case sharedSubscriptionsNotSupported
            
            /// The connection rate limit has been exceeded.
            case connectionRateExceeded
            
            /// The maximum connection time authorized for this connection has been exceeded.
            case maximumConnectTime
            
            /// The server does not support subscription identifiers.
            case subscriptionIdentifiersNotSupported
            
            /// The Server does not support wildcard subscriptions.
            case wildcardSubscriptionsNotSupported
        }
        
        /// The code indicating the reason for the error.
        public var code: Code
        
        /// An optional message giving more information regarding the reason for failure.
        public var message: String?
    }
}
