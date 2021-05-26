/// Errors that can occur while sending messages to the broker. This is generally a programming error when using this library.
public enum MQTTValueError: Error {
    /// The value being send to the broker is too large for the MQTT message.
    case valueTooLarge(String)
}
