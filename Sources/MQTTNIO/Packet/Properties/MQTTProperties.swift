import NIO

struct MQTTProperties {
    
    // MARK: - Vars
    
    @MQTTProperty(0x01)
    var payloadFormatIsUTF8 = false
    
    @MQTTProperty(0x02, format: UInt32.self)
    var messageExpiryInterval: TimeAmount?
    
    @MQTTProperty(0x03)
    var contentType: String?
    
    @MQTTProperty(0x08)
    var responseTopic: String?
    
    @MQTTProperty(0x09)
    var correlationData: ByteBuffer?
    
    @MQTTProperty(0x0B)
    var subscriptionIdentifier: Int?
    
    @MQTTProperty(0x0B)
    var subscriptionIdentifiers: [Int]
    
    @MQTTProperty(0x11)
    var sessionExpiry: MQTTConfiguration.SessionExpiry
    
    @MQTTProperty(0x12)
    var assignedClientIdentifier: String?
    
    @MQTTProperty(0x13, format: UInt16.self)
    var serverKeepAlive: TimeAmount?
    
    @MQTTProperty(0x15)
    var authenticationMethod: String?
    
    @MQTTProperty(0x16)
    var authenticationData: ByteBuffer?
    
    @MQTTProperty(0x17)
    var requestProblemInformation = true
    
    @MQTTProperty(0x18, format: UInt32.self)
    var willDelayInterval: TimeAmount?
    
    @MQTTProperty(0x19)
    var requestResponseInformation = false
    
    @MQTTProperty(0x1A)
    var responseInformation: String?
    
    @MQTTProperty(0x1C)
    var serverReference: String?
    
    @MQTTProperty(0x1F)
    var reasonString: String?
    
    @MQTTProperty(0x21, format: UInt16.self)
    var receiveMaximum: Int?
    
    @MQTTProperty(0x22, format: UInt16.self)
    var topicAliasMaximum: Int = 0
    
    @MQTTProperty(0x23, format: UInt16.self)
    var topicAlias: Int?
    
    @MQTTProperty(0x24)
    var maximumQoS: MQTTQoS
    
    @MQTTProperty(0x25)
    var retainAvailable = true
    
    @MQTTProperty(0x26)
    var userProperties: [MQTTUserProperty]
    
    @MQTTProperty(0x27, format: UInt32.self)
    var maximumPacketSize: Int?
    
    @MQTTProperty(0x28)
    var wildcardSubscriptionAvailable = true
    
    @MQTTProperty(0x29)
    var subscriptionIdentifierAvailable = true
    
    @MQTTProperty(0x2A)
    var sharedSubscriptionAvailable = true
    
    // MARK: - Parsing / Serializing
    
    static func parse(
        from data: inout ByteBuffer,
        using parser: MQTTPropertiesParser
    ) throws -> Self {
        var properties = MQTTProperties()
        
        let length = try data.readMQTTVariableByteInteger("Property length")
        let offset = data.readerIndex
        
        var mapping: [Int: MQTTPropertiesParser.Element] = [:]
        for entry in parser {
            mapping[entry.getIdentifier(properties)] = entry
        }
        
        var identifiers = Set<Int>()
        while data.readerIndex < offset + length {
            let identifier = try data.readMQTTVariableByteInteger("Property identifier")
            guard let entry = mapping[identifier] else {
                throw MQTTProtocolError("Unknown or invalid property '\(identifier)'")
            }
            
            guard entry.isAllowedMultipleTimes(properties) || !identifiers.contains(identifier) else {
                throw MQTTProtocolError("Invalid duplicate property '\(identifier)'")
            }
            
            identifiers.insert(identifier)
            
            try entry.parse(&properties, &data)
        }
        
        return properties
    }
    
    func serialize(to buffer: inout ByteBuffer) throws {
        var propertiesLength: Int = 0
        var propertiesToSerialize: [MQTTPropertyType] = []
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            guard let property = child.value as? MQTTPropertyType else {
                continue
            }
            
            let propertyLength = property.serializedLength
            guard propertyLength > 0 else {
                continue
            }
            
            propertiesLength += propertyLength
            propertiesToSerialize.append(property)
        }
        
        try buffer.writeMQTTVariableByteInteger(propertiesLength, "Property length")
        try propertiesToSerialize.forEach {
            try $0.serialize(into: &buffer)
        }
    }
}

typealias MQTTPropertiesParser = [MQTTPropertiesParserBuilder.Entry]

@resultBuilder
struct MQTTPropertiesParserBuilder {
    struct Entry {
        var getIdentifier: (MQTTProperties) -> Int
        var isAllowedMultipleTimes: (MQTTProperties) -> Bool
        var parse: (inout MQTTProperties, inout ByteBuffer) throws -> Void
    }
    
    static func buildBlock(_ components: [Entry]...) -> [Entry] {
        return components.flatMap { $0 }
    }
    
    static func buildExpression<Value, Intermediate, PropertyValue>(
        _ keyPath: WritableKeyPath<MQTTProperties, MQTTProperty<Value, Intermediate, PropertyValue>>
    ) -> [Entry] {
        return [
            Entry { properties in
                return properties[keyPath: keyPath].identifier
            } isAllowedMultipleTimes: { properties in
                return properties[keyPath: keyPath].isAllowedMultipleTimes
            } parse: { properties, buffer in
                try properties[keyPath: keyPath].parse(from: &buffer)
            }
        ]
    }
}
