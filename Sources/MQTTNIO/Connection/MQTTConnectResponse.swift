/// Response returned when the `MQTTClient` is connected to a broker.
public struct MQTTConnectResponse {
    
    /// Indicates whether there is a session present for the client on the broker.
    public var isSessionPresent: Bool
}
