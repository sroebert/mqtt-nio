import Foundation

public enum MQTTServerError: Error, LocalizedError, CustomStringConvertible {
    case unknown
    case unacceptableProtocolVersion
    case identifierRejected
    case serverUnavailable
    case badUsernameOrPassword
    case notAuthorized
    
    /// See `LocalizedError`.
    public var errorDescription: String? {
        return description
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        let description: String
        switch self {
        case .unknown:
            description = "There was an unknown error when connecting to the server."
        case .unacceptableProtocolVersion:
            description = "The server does not support the level of the MQTT protocol requested by the client."
        case .identifierRejected:
            description = "The client identifier is not allowed by the Server."
        case .serverUnavailable:
            description = "The network connection has been made but the MQTT service is unavailable."
        case .badUsernameOrPassword:
            description = "The data in the user name or password is malformed."
        case .notAuthorized:
            description = "The client is not authorized to connect."
        }
        return "MQTTServerError: \(description)"
    }
}
