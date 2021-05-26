/// Errors that can occur while publishing a message to the broker.
public enum MQTTPublishError: Error, Equatable {
    /// The client reconnected to the broker and the session was cleared. Because of this, the publish was cancelled.
    case sessionCleared
    
    /// The broker send a reason for publish failure.
    case server(ServerReason)
}

extension MQTTPublishError {
    /// The reason returned from the server, indicating why the publish failed.
    public struct ServerReason: Equatable {
        
        public enum Code: Equatable {
            /// The server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
            case unspecifiedError
            
            /// The data that was send is valid but is not accepted by the server.
            case implementationSpecificError
            
            /// The user is not authorized to perform this operation.
            case notAuthorized
            
            /// The message topic is not accepted.
            case topicNameInvalid
            
            /// The packet identifier send was already in use.
            case packetIdentifierInUse
            
            /// An implementation or administrative imposed limit has been exceeded.
            case quotaExceeded
            
            /// The message payload format is invalid.
            case payloadFormatInvalid
        }
    
        /// The code indicating the reason for the error.
        public var code: Code
        
        /// An optional message giving more information regarding the reason for failure.
        public var message: String?
    }
}
