import NIO
import Logging

final class MQTTPacketEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder`.
    typealias OutboundIn = MQTTPacket

    /// Logger to send debug messages to.
    let logger: Logger

    /// Creates a new `MQTTPacketEncoder`.
    init(logger: Logger) {
        self.logger = logger
    }
    
    /// See `MessageToByteEncoder`.
    func encode(data packet: MQTTPacket, out: inout ByteBuffer) throws {
        var packet = packet
        // serialize header
        out.writeInteger(packet.kind.value | packet.fixedHeaderData)
        
        // write size
        try writePacketSize(packet.data.readableBytes, out: &out)
        
        // serialize the packet data
        out.writeBuffer(&packet.data)
        
        logger.trace("Encoded: \(packet.kind)")
    }
    
    private func writePacketSize(_ size: Int, out: inout ByteBuffer) throws {
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
