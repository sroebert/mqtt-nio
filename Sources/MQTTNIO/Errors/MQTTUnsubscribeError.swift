/// Errors that can occur when unsubscribing from a topic on the broker.
public enum MQTTUnsubscribeError: Error, MQTTSendable {
    /// One or more of the topic filters to unsubscribe from are invalid.
    case invalidTopic
}
