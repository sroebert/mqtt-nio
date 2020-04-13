import Foundation

/// Errors that can be received when trying to connect to a broker.
public enum MQTTConnectionError: Error {
    /// The connection was closed while trying to connect.
    case connectionClosed
    
    /// The broker took to long to respond to the connect packet.
    case timeoutWaitingForAcknowledgement
    
    /// The client identifier was rejected by the broker.
    case identifierRejected
    
    /// The broker indicated that it is unavailable.
    case serverUnavailable
    
    /// The client provided a bad username or password.
    case badUsernameOrPassword
    
    /// The client is unauthorized.
    case notAuthorized
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
