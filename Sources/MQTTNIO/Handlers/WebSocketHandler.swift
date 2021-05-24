import NIO
import NIOWebSocket

final class WebSocketHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = WebSocketFrame
    typealias InboundOut = ByteBuffer
    
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = WebSocketFrame
    
    struct FrameSequence {
        enum FrameType {
            case text
            case binary
        }
        
        let type: FrameType
        private(set) var buffer = Allocator.shared.buffer(capacity: 0)

        mutating func append(_ data: ByteBuffer) {
            var data = data
            buffer.writeBuffer(&data)
        }
    }
    
    // MARK: - Vars

    private var frameSequence: FrameSequence?
    private var isClosed = false
    
    private var maskingKey: WebSocketMaskingKey? {
        let bytes = (0...3).map { _ in UInt8.random(in: 1...255) }
        return WebSocketMaskingKey(bytes)
    }
    
    // MARK: - ChannelDuplexHandler
    
    func channelInactive(context: ChannelHandlerContext) {
        close(context: context, code: .unknown(1006), promise: nil)

        context.fireChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)

        switch frame.opcode {
        case .text:
            guard frameSequence == nil else {
                close(context: context, code: .protocolError, promise: nil)
                return
            }
            
            var frameSequence = FrameSequence(type: .text)
            frameSequence.append(frame.data)
            self.frameSequence = frameSequence
            
        case .binary:
            guard frameSequence == nil else {
                close(context: context, code: .protocolError, promise: nil)
                return
            }
            
            var frameSequence = FrameSequence(type: .binary)
            frameSequence.append(frame.data)
            self.frameSequence = frameSequence
            
        case .continuation:
            guard var frameSequence = self.frameSequence else {
                close(context: context, code: .protocolError, promise: nil)
                return
            }
            
            frameSequence.append(frame.data)
            self.frameSequence = frameSequence
            
        case .connectionClose:
            isClosed = true
            context.close(promise: nil)

        default:
            break
        }
        
        if frame.fin {
            frameSequence.map {
               context.fireChannelRead(wrapInboundOut($0.buffer))
            }
            frameSequence = nil
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard context.channel.isActive else {
            return
        }

        let buffer = unwrapOutboundIn(data)
        send(context: context, buffer: buffer, opcode: .binary, promise: promise)
    }
    
    func close(context: ChannelHandlerContext, code: WebSocketErrorCode = .goingAway, promise: EventLoopPromise<Void>?) {
        guard !isClosed else {
            promise?.succeed(())
            return
        }
        
        isClosed = true
        
        let codeAsInt = UInt16(webSocketErrorCode: code)
        let codeToSend: WebSocketErrorCode
        if codeAsInt == 1005 || codeAsInt == 1006 {
            /// Code 1005 and 1006 are used to report errors to the application, but must never be sent over
            /// the wire (per https://tools.ietf.org/html/rfc6455#section-7.4)
            codeToSend = .normalClosure
        } else {
            codeToSend = code
        }

        var buffer = context.channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: codeToSend)
        
        send(context: context, buffer: buffer, opcode: .connectionClose, promise: promise)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        let errorCode: WebSocketErrorCode
        if let error = error as? NIOWebSocketError {
            errorCode = WebSocketErrorCode(error)
        } else {
            errorCode = .unexpectedServerError
        }
        close(context: context, code: errorCode, promise: nil)

        context.fireErrorCaught(error)
    }
    
    // MARK: - Utils

    private func send(
        context: ChannelHandlerContext,
        buffer: ByteBuffer,
        opcode: WebSocketOpcode,
        promise: EventLoopPromise<Void>? = nil
    ) {
        let frame = WebSocketFrame(fin: true, opcode: opcode, maskKey: maskingKey, data: buffer)
        context.writeAndFlush(wrapOutboundOut(frame), promise: promise)
    }
}

extension WebSocketErrorCode {
    fileprivate init(_ error: NIOWebSocketError) {
        switch error {
        case .invalidFrameLength:
            self = .messageTooLarge
        case .fragmentedControlFrame,
             .multiByteControlFrameLength:
            self = .protocolError
        }
    }
}
