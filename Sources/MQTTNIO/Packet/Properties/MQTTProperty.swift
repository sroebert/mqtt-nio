import NIO

enum MQTTProperty {
    case payloadFormatIndicator(UInt8)
    case messageExpiryInterval(UInt32)
    case contentType(String)
    case responseTopic(String)
    case correlationData(ByteBuffer)
    case subscriptionIdentifier(MQTTVariableByteInteger)
    case sessionExpiryInterval(UInt32)
    case assignedClientIdentifier(String)
    case serverKeepAlive(UInt16)
    case authenticationMethod(String)
    case authenticationData(ByteBuffer)
    case requestProblemInformation(UInt8)
    case willDelayInterval(UInt32)
    case requestResponseInformation(UInt8)
    case responseInformation(String)
    case serverReference(String)
    case reasonString(String)
    case receiveMaximum(UInt16)
    case topicAliasMaximum(UInt16)
    case topicAlias(UInt16)
    case maximumQoS(UInt8)
    case retainAvailable(UInt8)
    case userProperty(MQTTStringPair)
    case maximumPacketSize(UInt32)
    case wildcardSubscriptionAvailable(UInt8)
    case subscriptionIdentifierAvailable(UInt8)
    case sharedSubscriptionAvailable(UInt8)
    
    // MARK: - Parse / Serialize
    
    static func parse(from data: inout ByteBuffer, identifier: Identifier) throws -> Self {
        switch identifier {
        case .payloadFormatIndicator: return try .payloadFormatIndicator(.parsePropertyValue(from: &data))
        case .messageExpiryInterval: return try .messageExpiryInterval(.parsePropertyValue(from: &data))
        case .contentType: return try .contentType(.parsePropertyValue(from: &data))
        case .responseTopic: return try .responseTopic(.parsePropertyValue(from: &data))
        case .correlationData: return try .correlationData(.parsePropertyValue(from: &data))
        case .subscriptionIdentifier: return try .subscriptionIdentifier(.parsePropertyValue(from: &data))
        case .sessionExpiryInterval: return try .sessionExpiryInterval(.parsePropertyValue(from: &data))
        case .assignedClientIdentifier: return try .assignedClientIdentifier(.parsePropertyValue(from: &data))
        case .serverKeepAlive: return try .serverKeepAlive(.parsePropertyValue(from: &data))
        case .authenticationMethod: return try .authenticationMethod(.parsePropertyValue(from: &data))
        case .authenticationData: return try .authenticationData(.parsePropertyValue(from: &data))
        case .requestProblemInformation: return try .requestProblemInformation(.parsePropertyValue(from: &data))
        case .willDelayInterval: return try .willDelayInterval(.parsePropertyValue(from: &data))
        case .requestResponseInformation: return try .requestResponseInformation(.parsePropertyValue(from: &data))
        case .responseInformation: return try .responseInformation(.parsePropertyValue(from: &data))
        case .serverReference: return try .serverReference(.parsePropertyValue(from: &data))
        case .reasonString: return try .reasonString(.parsePropertyValue(from: &data))
        case .receiveMaximum: return try .receiveMaximum(.parsePropertyValue(from: &data))
        case .topicAliasMaximum: return try .topicAliasMaximum(.parsePropertyValue(from: &data))
        case .topicAlias: return try .topicAlias(.parsePropertyValue(from: &data))
        case .maximumQoS: return try .maximumQoS(.parsePropertyValue(from: &data))
        case .retainAvailable: return try .retainAvailable(.parsePropertyValue(from: &data))
        case .userProperty: return try .userProperty(.parsePropertyValue(from: &data))
        case .maximumPacketSize: return try .maximumPacketSize(.parsePropertyValue(from: &data))
        case .wildcardSubscriptionAvailable: return try .wildcardSubscriptionAvailable(.parsePropertyValue(from: &data))
        case .subscriptionIdentifierAvailable: return try .subscriptionIdentifierAvailable(.parsePropertyValue(from: &data))
        case .sharedSubscriptionAvailable: return try .sharedSubscriptionAvailable(.parsePropertyValue(from: &data))
        }
    }
    
    var value: MQTTPropertyValue {
        switch self {
        case .payloadFormatIndicator(let value): return value
        case .messageExpiryInterval(let value): return value
        case .contentType(let value): return value
        case .responseTopic(let value): return value
        case .correlationData(let value): return value
        case .subscriptionIdentifier(let value): return value
        case .sessionExpiryInterval(let value): return value
        case .assignedClientIdentifier(let value): return value
        case .serverKeepAlive(let value): return value
        case .authenticationMethod(let value): return value
        case .authenticationData(let value): return value
        case .requestProblemInformation(let value): return value
        case .willDelayInterval(let value): return value
        case .requestResponseInformation(let value): return value
        case .responseInformation(let value): return value
        case .serverReference(let value): return value
        case .reasonString(let value): return value
        case .receiveMaximum(let value): return value
        case .topicAliasMaximum(let value): return value
        case .topicAlias(let value): return value
        case .maximumQoS(let value): return value
        case .retainAvailable(let value): return value
        case .userProperty(let value): return value
        case .maximumPacketSize(let value): return value
        case .wildcardSubscriptionAvailable(let value): return value
        case .subscriptionIdentifierAvailable(let value): return value
        case .sharedSubscriptionAvailable(let value): return value
        }
    }
}

extension ByteBuffer {
    mutating func readMQTTProperties(
        allowed: [MQTTProperty.Identifier]
    ) throws -> [MQTTProperty] {
        let length = try readMQTTVariableByteInteger("Property length")
        let offset = readerIndex
        
        var properties: [MQTTProperty] = []
        while readerIndex < offset + length {
            let identifierValue = try readMQTTVariableByteInteger("Property identifier")
            guard let identifier = MQTTProperty.Identifier(rawValue: identifierValue) else {
                throw MQTTProtocolError.parsingError("Unknown property identifier \(identifierValue)")
            }
            
            guard allowed.contains(identifier) else {
                throw MQTTProtocolError.parsingError("Invalid property identifier \(identifierValue)")
            }
            
            let property = try MQTTProperty.parse(from: &self, identifier: identifier)
            properties.append(property)
        }
        
        return properties
    }
    
    mutating func writeMQTTProperties(_ properties: [MQTTProperty]) throws {
        let tuples = properties.map {
            (identifier: $0.identifier, value: $0.value)
        }
        
        let length = tuples.reduce(0) { $0 + $1.value.propertyValueLength }
        try writeMQTTVariableByteInteger(length, "Property length")
        
        for (identifier, value) in tuples {
            try writeMQTTVariableByteInteger(identifier.rawValue, "Property identifier")
            try value.serializePropertyValue(into: &self)
        }
    }
}
