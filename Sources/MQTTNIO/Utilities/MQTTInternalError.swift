import Foundation

public struct MQTTInternalError: Error, LocalizedError, CustomStringConvertible {
    public let message: String
    
    public var errorDescription: String? {
        return description
    }
    
    public var description: String {
        return "MQTTInternalError: \(message)"
    }
}
