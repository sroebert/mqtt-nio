import Foundation

public enum MQTTConnectionError: Error, LocalizedError, CustomStringConvertible {
    case `protocol`(String)
    case connectionClosed
    
    /// See `LocalizedError`.
    public var errorDescription: String? {
        return description
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        let description: String
        switch self {
        case .protocol(let message): description = message
        case .connectionClosed: description = "closed"
        }
        return "MQTTConnectionError: \(description)"
    }
}
