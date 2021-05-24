import Foundation

/// This structure contains data to indicate that a given message is a request.
///
/// A request can be answered by a response message. The response message will be published
/// to the given response topic and will contain the (optional) correlation data set in this structure.
public struct MQTTRequestConfiguration {
    
    /// The response topic for the response on this request.
    public var responseTopic: String
    
    /// Optional data that will be sent with the response message that was sent to the response topic.
    public var correlationData: Data?
    
    /// Creates an `MQTTRequestConfiguration`.
    /// - Parameters:
    ///   - responseTopic: The response topic for the response on this request.
    ///   - correlationData: Optional data that will be sent with the response message that was sent to the response topic. The default value is `nil`.
    public init(
        responseTopic: String,
        correlationData: Data?
    ) {
        self.responseTopic = responseTopic
        self.correlationData = correlationData
    }
}
