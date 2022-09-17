import Foundation

/// Authentication handler protocol to handle enhanced authentication with a 5.0 MQTT broker.
public protocol MQTTAuthenticationHandler: MQTTPreconcurrencySendable {
    /// The name of the authentication method to use.
    var authenticationMethod: String { get }
    
    /// The initial data to send as authentication data when starting the authentication process.
    var initialAuthenticationData: Data? { get }
    
    /// Called when the broker sends a 'Continue authentication' message to the client.
    ///
    /// This method can throw an error, in which case the connection with the broker will be closed. The
    /// error will be forwared to the `EventLoopFuture`s returned from the `MQTTClient`.
    ///
    /// - Parameter data: The (optional) data received from the broker.
    /// - Returns: Optional data which will be sent back to the broker.
    func processAuthenticationData(_ data: Data?) throws -> Data?
}
