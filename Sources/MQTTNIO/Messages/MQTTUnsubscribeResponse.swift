/// The response returned from the broker when unsubscribing from a single topic.
public struct MQTTSingleUnsubscribeResponse: MQTTSendable {
    /// The result for unsubscribing.
    public var result: MQTTUnsubscribeResult
    
    /// User properties send from the broker with this response.
    public var userProperties: [MQTTUserProperty]
    
    /// Optional reason string representing the reason associated with this response.
    public var reasonString: String?
}

/// The response returned from the broker when unsubscribing.
public struct MQTTUnsubscribeResponse: MQTTSendable {
    /// The results for each topic the client tried to unsubscribe from.
    public var results: [MQTTUnsubscribeResult]
    
    /// User properties send from the broker with this response.
    public var userProperties: [MQTTUserProperty]
    
    /// Optional reason string representing the reason associated with this response.
    public var reasonString: String?
}

/// The result returned from the broker for each topic when unsubscribing, indicating the result.
///
/// For each topic trying to unsubscribe from, an `MQTTUnsubscribeResult` will be returned from the broker.
public enum MQTTUnsubscribeResult: Equatable, MQTTSendable {
    /// Succesfully unsubscribed.
    case success
    
    /// Failed to unsubscribe with a given reason.
    case failure(ServerErrorReason)
}

extension MQTTUnsubscribeResult {
    /// The reason returned from the server, indicating why unsubscribing failed.
    public enum ServerErrorReason: MQTTSendable {
        /// The server does not wish to reveal the reason for the failure, or none of the other reason codes apply.
        case unspecifiedError
        
        /// The data that was send is valid but is not accepted by the server.
        case implementationSpecificError
        
        /// The user is not authorized to perform this operation.
        case notAuthorized
        
        /// The unsubscribe topic is not accepted.
        case topicFilterInvalid
        
        /// The packet identifier send was already in use.
        case packetIdentifierInUse
    }
}
