/// Context object passed to listeners registered with the `MQTTClient`.
///
/// This object allows the listener to stop the listening by calling `stopListening`.
public protocol MQTTListenerContext {
    /// Stops listening, making sure the listener will not be called anymore.
    func stopListening()
}

/// Response returned when the `MQTTClient` is connected to a broker.
public struct MQTTConnectResponse {
    
    /// Indicates whether there is a session present for the client on the broker.
    public var isSessionPresent: Bool
}

/// The reason the `MQTTClient` was disconnected.
public enum MQTTDisconnectReason {
    case userInitiated
    case connectionClosed
    case error(Error)
}

/// Listener called when the `MQTTClient` is connected.
///
/// - Parameters:
///   - client: The client that has connected.
///   - response: The connection response from the broker.
///   - context: The listening context for this listener.
public typealias MQTTConnectListener = (_ client: MQTTClient, _ response: MQTTConnectResponse, _ context: MQTTListenerContext) -> Void

/// Listener called when the `MQTTClient` has been disconnected.
///
/// - Parameters:
///   - client: The client that has been disconnected.
///   - reason: The reason for disconnecting.
///   - context: The listening context for this listener.
public typealias MQTTDisconnectListener = (_ client: MQTTClient, _ reason: MQTTDisconnectReason, _ context: MQTTListenerContext) -> Void

/// Listener called when the `MQTTClient` has caught an error, either while receiving or sending data.
///
/// - Parameters:
///   - client: The client that has caught an error..
///   - error: The error that has been caught..
///   - context: The listening context for this listener.
public typealias MQTTErrorListener = (_ client: MQTTClient, _ error: Error, _ context: MQTTListenerContext) -> Void

/// Listener called when the `MQTTClient` has received an `MQTTMessage` from the broker.
///
/// - Parameters:
///   - client: The client that has received a message.
///   - message: The message that was received.
///   - context: The listening context for this listener.
public typealias MQTTMessageListener = (_ client: MQTTClient, _ message: MQTTMessage, _ context: MQTTListenerContext) -> Void

/// Extension to make `CallbackList.Entry` conform to `MQTTListenerContext`.
extension CallbackList.Entry: MQTTListenerContext {
    func stopListening() {
        remove()
    }
}
