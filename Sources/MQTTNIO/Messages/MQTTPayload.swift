import NIO

/// A payload send with an MQTT message
public enum MQTTPayload: ExpressibleByStringLiteral, CustomDebugStringConvertible {
    /// An empty payload.
    case empty
    /// A payload in bytes.
    case bytes(ByteBuffer)
    /// A UTF-8 string payload with an optional content type.
    case string(String, contentType: String? = nil)
    
    /// The payload parsed as an UTF-8 string.
    public var string: String? {
        switch self {
        case .empty:
            return nil
            
        case .bytes(let buffer):
            return String(buffer: buffer)
            
        case .string(let string, _):
            return string
        }
    }
    
    /// The content type of the payload, or `nil` if it is unknown.
    public var contentType: String? {
        switch self {
        case .empty, .bytes:
            return nil
            
        case .string(_, let contentType):
            return contentType
        }
    }
    
    // MARK: - ExpressibleByStringLiteral
    
    public init(stringLiteral value: String) {
        self = .string(value, contentType: nil)
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        switch self {
        case .empty:
            return "empty"
            
        case .bytes(let buffer):
            if buffer.readableBytes == 1 {
                return "1 byte"
            }
            return "\(buffer.readableBytes) bytes"
            
        case .string(let string, contentType: let contentType?):
            return "\(contentType): \(string)"
            
        case .string(let string, contentType: nil):
            return string
        }
    }
}
