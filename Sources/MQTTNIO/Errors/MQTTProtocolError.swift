/// Errors that can occur while communicating with the broker.
public struct MQTTProtocolError: Error, MQTTSendable {
    /// The code indicating the error reason.
    public var code: Code
    
    /// A string contains a more ellaborate description of the error.
    public var message: String
    
    // MARK: - Init
    
    init(
        code: Code = .malformedPacket,
        _ message: String
    ) {
        self.code = code
        self.message = message
    }
}

extension MQTTProtocolError {
    public enum Code: MQTTSendable {
        /// The received packet does not conform to this specification.
        case malformedPacket
        
        /// An unexpected or out of order packet was received.
        case protocolError
        
        /// The topic alias was greater than the allowed maximum.
        case topicAliasInvalid
        
        /// The packet that was sent exceeded the maximum permissible size.
        case packetTooLarge
        
        var disconnectReasonCode: MQTTPacket.Disconnect.ReasonCode {
            switch self {
            case .malformedPacket:
                return .malformedPacket
            case .protocolError:
                return .protocolError
            case .topicAliasInvalid:
                return .topicAliasInvalid
            case .packetTooLarge:
                return .packetTooLarge
            }
        }
    }
}
