import NIO
import Logging

final class MQTTPacketEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder`.
    typealias OutboundIn = MQTTPacket

    /// Logger to send debug messages to.
    let logger: Logger?

    /// Creates a new `MQTTPacketEncoder`.
    init(logger: Logger? = nil) {
        self.logger = logger
    }
    
    /// See `MessageToByteEncoder`.
    func encode(data message: MQTTPacket, out: inout ByteBuffer) throws {
        var message = message
        // serialize header
        out.writeInteger(message.kind.value | message.fixedHeaderData)
        
        // write size
        try writeMessageSize(message.data.readableBytes, out: &out)
        
        // serialize the message data
        out.writeBuffer(&message.data)
        
        self.logger?.trace("Encoded: MQTTPacket (\(message.kind))")
    }
    
    private func writeMessageSize(_ size: Int, out: inout ByteBuffer) throws {
        var size = size
        var counter = 0
        
        repeat {
            guard counter < 4 else {
                throw MQTTConnectionError.protocol("The data of the message to encode is too large")
            }
            
            var byte = UInt8(size % 128)
            size /= 128
            if size > 0 {
                byte |= 0b10000000
            }
            out.writeInteger(byte)
            
            counter += 1
            
        } while size > 0
    }
}

protocol ByteBufferSerializable {
    func serialize(into buffer: inout ByteBuffer)
}
