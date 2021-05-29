import Foundation

/// Indicates which part of the enhanced authentication process is being performed.
public enum MQTTAuthenticationProcess {
    /// The initial authentication process when connecting to a 5.0 MQTT broker.
    case connect
    
    /// The re-authentication while already connected to a 5.0 MQTT broker.
    case reAuthenticate
}

/// Authentication handler protocol to handle enhanced authentication with a 5.0 MQTT broker.
public protocol MQTTAuthenticationHandler {
    /// The name of the authentication method to use.
    var authenticationMethod: String { get }
    
    /// The initial data to send as authentication data when starting the authentication process.
    var initialAuthenticationData: Data? { get }
    
    /// Called when the broker sends a 'Continue authentication' message to the client.
    ///
    /// This method can throw an error, in which case the connection with the broker will be closed. The
    /// error will be passed to any listeners of the `MQTTClient`.
    ///
    /// - Parameter data: The (optional) data received from the broker.
    /// - Returns: Optional data which will be sent back to the broker.
    func processAuthenticationData(_ data: Data?) throws -> Data?
}
