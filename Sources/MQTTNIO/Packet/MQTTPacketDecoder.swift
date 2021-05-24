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
        guard let messageSize = try peekBuffer.peekMQTTVariableByteInteger("Packet size") else {
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
}
