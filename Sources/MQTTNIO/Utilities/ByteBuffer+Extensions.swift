import NIO

extension ByteBuffer {
    mutating func readMQTTString(_ errorVariableName: String) throws -> String {
        guard let length = readInteger(as: UInt16.self) else {
            throw MQTTProtocolError.parsingError("Missing data for '\(errorVariableName)'")
        }
        
        guard let string = readString(length: Int(length)) else {
            throw MQTTProtocolError.parsingError("Missing data for '\(errorVariableName)'")
        }
        
        return string
    }
    
    mutating func writeMQTTString(_ string: String, _ errorVariableName: String) throws {
        guard string.count <= UInt16.max else {
            throw MQTTValueError.valueTooLarge(errorVariableName)
        }
        
        writeInteger(UInt16(string.count))
        writeString(string)
    }
    
    mutating func writeMQTTDataWithLength(_ payload: inout ByteBuffer, _ errorVariableName: String) throws {
        
        // Leave room for length
        let lengthIndex = writerIndex
        moveWriterIndex(forwardBy: 2)
        
        let length = writeBuffer(&payload)
        guard length <= UInt16.max else {
            throw MQTTValueError.valueTooLarge(errorVariableName)
        }
        
        setInteger(UInt16(length), at: lengthIndex)
    }
}
