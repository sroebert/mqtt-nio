import NIO

protocol MQTTPropertyValue {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self
    func serializePropertyValue(into data: inout ByteBuffer) throws
    
    var propertyValueLength: Int { get }
}

extension FixedWidthInteger {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self {
        guard let value = data.readInteger(as: Self.self) else {
            throw MQTTProtocolError("Invalid Byte property value")
        }
        return value
    }
    
    func serializePropertyValue(into data: inout ByteBuffer) throws {
        data.writeInteger(self)
    }
    
    var propertyValueLength: Int {
        return MemoryLayout<Self>.size
    }
}

extension UInt8: MQTTPropertyValue {}
extension UInt16: MQTTPropertyValue {}
extension UInt32: MQTTPropertyValue {}

extension String: MQTTPropertyValue {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self {
        return try data.readMQTTString("Property value")
    }
    
    func serializePropertyValue(into data: inout ByteBuffer) throws {
        try data.writeMQTTString(self, "Property value")
    }
    
    var propertyValueLength: Int {
        return MemoryLayout<UInt16>.size + utf8.count
    }
}

extension MQTTStringPair: MQTTPropertyValue {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self {
        let key = try data.readMQTTString("Property value, string pair key")
        let value = try data.readMQTTString("Property value, string pair value")
        return MQTTStringPair(key: key, value: value)
    }
    
    func serializePropertyValue(into data: inout ByteBuffer) throws {
        try data.writeMQTTString(key, "Property value, string pair key")
        try data.writeMQTTString(value, "Property value, string pair value")
    }
    
    var propertyValueLength: Int {
        return key.propertyValueLength + value.propertyValueLength
    }
}

extension MQTTVariableByteInteger: MQTTPropertyValue {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self {
        let value = try data.readMQTTVariableByteInteger("Property value")
        return self.init(value: value)
    }
    
    func serializePropertyValue(into data: inout ByteBuffer) throws {
        try data.writeMQTTVariableByteInteger(value, "Property value")
    }
    
    var propertyValueLength: Int {
        return ByteBuffer.sizeForMQTTVariableByteInteger(value)
    }
}

extension ByteBuffer: MQTTPropertyValue {
    static func parsePropertyValue(from data: inout ByteBuffer) throws -> Self {
        return try data.readMQTTDataWithLength("Property value")
    }
    
    func serializePropertyValue(into data: inout ByteBuffer) throws {
        var buffer = self
        try data.writeMQTTDataWithLength(&buffer, "Property value")
    }
    
    var propertyValueLength: Int {
        return MemoryLayout<UInt16>.size + readableBytes
    }
}
