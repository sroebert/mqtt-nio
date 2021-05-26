import Foundation
import NIO

enum Allocator {
    static let shared = ByteBufferAllocator()
}

extension ByteBuffer {
    mutating func readMQTTString(_ errorVariableName: String) throws -> String {
        guard let length = readInteger(as: UInt16.self) else {
            throw MQTTProtocolError("Missing data for '\(errorVariableName)'")
        }
        
        guard let string = readString(length: Int(length)) else {
            throw MQTTProtocolError("Missing data for '\(errorVariableName)'")
        }
        
        return string
    }
    
    mutating func writeMQTTString(_ string: String, _ errorVariableName: String) throws {
        guard string.utf8.count <= UInt16.max else {
            throw MQTTValueError.valueTooLarge(errorVariableName)
        }
        
        writeInteger(UInt16(string.utf8.count))
        writeString(string)
    }
    
    mutating func peekMQTTVariableByteInteger(_ errorVariableName: String) throws -> Int? {
        var value = 0
        var multiplier = 1
        var counter = 0
        
        var lastByte: UInt8
        repeat {
            guard counter < 4 else {
                throw MQTTProtocolError("Invalid variably byte integer received for '\(errorVariableName)'.")
            }
            
            guard let byte = readInteger(as: UInt8.self) else {
                return nil
            }
            
            value += Int(0b01111111 & byte) * multiplier
            
            lastByte = byte
            counter += 1
            multiplier *= 128
            
        } while (lastByte & 0b10000000) != 0
        
        return value
    }
    
    mutating func readMQTTVariableByteInteger(_ errorVariableName: String) throws -> Int {
        guard let value = try peekMQTTVariableByteInteger(errorVariableName) else {
            throw MQTTProtocolError("Invalid variably byte integer received for '\(errorVariableName)'.")
        }
        return value
    }
    
    mutating func writeMQTTVariableByteInteger(_ value: Int, _ errorVariableName: String) throws {
        var value = value
        var counter = 0
        
        repeat {
            guard counter < 4 else {
                throw MQTTProtocolError("'\(errorVariableName)' too large.")
            }
            
            var byte = UInt8(value % 128)
            value /= 128
            if value > 0 {
                byte |= 0b10000000
            }
            writeInteger(byte)
            
            counter += 1
            
        } while value > 0
    }
    
    mutating func readMQTTDataWithLength(_ errorVariableName: String) throws -> ByteBuffer {
        
        guard let length = readInteger(as: UInt16.self) else {
            throw MQTTProtocolError("Invalid binary data received for '\(errorVariableName)")
        }
        
        guard let data = readBytes(length: Int(length)) else {
            throw MQTTProtocolError("Too little binary data received for '\(errorVariableName)")
        }
        
        return Allocator.shared.buffer(bytes: data)
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

extension String {
    var byteBuffer: ByteBuffer {
        return Allocator.shared.buffer(string: self)
    }
}

extension Sequence where Element == UInt8 {
    var byteBuffer: ByteBuffer {
        return Allocator.shared.buffer(bytes: self)
    }
}
