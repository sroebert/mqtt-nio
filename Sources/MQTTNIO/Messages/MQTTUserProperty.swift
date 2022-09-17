/// Used to send or receive additional data with certain MQTT packets.
public struct MQTTUserProperty: Equatable, MQTTSendable {
    
    /// The name of the user property.
    public var name: String
    
    /// The value of the user property.
    public var value: String
    
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension Array: ExpressibleByDictionaryLiteral where Element == MQTTUserProperty {
    public init(dictionaryLiteral elements: (String, String)...) {
        self = elements.map {
            MQTTUserProperty(name: $0, value: $1)
        }
    }
}
