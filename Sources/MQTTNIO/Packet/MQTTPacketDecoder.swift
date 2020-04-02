import NIO
import Logging

final class MQTTPacketDecoder: ByteToMessageDecoder {
    /// See `ByteToMessageDecoder`.
    typealias InboundOut = MQTTPacket

    /// Logger to send debug messages to.
    let logger: Logger
    
    /// Creates a new `MQTTPacketDecoder`.
    init(logger: Logger) {
        self.logger = logger
    }
    
    /// See `ByteToMessageDecoder`.
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var peekBuffer = buffer
        
        // peek at the message kind
        // the message kind is always the first byte of a message
        guard let headerByte = peekBuffer.readInteger(as: UInt8.self) else {
            return .needMoreData
        }

        // peek at the message size
        guard let messageSize = try peekMessageSize(using: &peekBuffer) else {
            return .needMoreData
        }
        
        // ensure message is large enough (skipping message type) or reject
        guard let data = peekBuffer.readSlice(length: messageSize) else {
            return .needMoreData
        }
        
        let message = MQTTPacket(headerByte: headerByte, data: data)
        
        // there is sufficient data, use this buffer
        buffer = peekBuffer
        logger.trace("Decoded: MQTTPacket (\(message.kind))")
        context.fireChannelRead(wrapInboundOut(message))
        return .continue
    }
    
    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        // ignore
        return .needMoreData
    }
    
    private func peekMessageSize(using peekBuffer: inout ByteBuffer) throws -> Int? {
        // the message size is between 1 and 4 bytes appearing immediately after the message header
        var size = 0
        var multiplier = 1
        var counter = 0
        
        var lastByte: UInt8
        repeat {
            guard counter < 4 else {
                throw MQTTConnectionError.protocol("Invalid message size received")
            }
            
            guard let byte = peekBuffer.readInteger(as: UInt8.self) else {
                return nil
            }
            
            size += Int(0b01111111 & byte) * multiplier
            
            lastByte = byte
            counter += 1
            multiplier *= 128
            
        } while (lastByte & 0b10000000) != 0
        
        return size
    }
}
