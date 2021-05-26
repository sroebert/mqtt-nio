/// Errors that can occur while communicating with the broker.
public struct MQTTProtocolError: Error {
    /// A string contains a more ellaborate description of the error.
    public var message: String
    
    // MARK: - Init
    
    init(_ message: String) {
        self.message = message
    }
}
