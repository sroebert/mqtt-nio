import Foundation

/// Authentication handler protocol to handle enhanced authentication with a 5.0 MQTT broker.
public protocol MQTTAuthenticationHandler: AnyObject {
    /// The name of the authentication method to use.
    var method: String { get }
    
    /// The initial data to send as authentication data when connecting to the broker.
    var initialData: Data? { get }
    
    /// Called when the broker sends a 'Continue authentication' message to the client.
    /// - Parameters:
    ///   - data: The (optional) data received from the broker.
    ///   - completion: A completion handler that should be called once the authentication data was processed. Optionally data can be passed which will be sent to the broker.
    func handleAuthentication(data: Data?, completion: @escaping (Data?) -> Void)
    
    /// Called when the broker sends a 'Re-authentication' message to the client.
    /// - Parameters:
    ///   - data: The (optional) data received from the broker.
    ///   - completion: A completion handler that should be called once the authentication data was processed. Optionally data can be passed which will be sent to the broker.
    func handleReauthentication(data: Data?, completion: @escaping (Data?) -> Void)
}
