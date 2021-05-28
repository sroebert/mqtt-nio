/// Errors that can occur when subscribing to a topic on the broker.
public enum MQTTSubscribeError: Error, Equatable {
    /// The subscription contains a topic filter with a wildcard, which is not supported on the broker.
    case subscriptionWildcardsNotSupported
    
    /// The subscription included a subscription identifier, which is not supported on the broker.
    case subscriptionIdentifiersNotSupported
    
    /// The subscription contains shared subscription, which is not supported on the broker.
    case sharedSubscriptionsNotSupported
}
