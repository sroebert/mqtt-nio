import NIO
import NIOHTTP1
import Logging

// Handler for upgrading the WebSocket connection.
final class WebSocketInitialRequestHandler: ChannelInboundHandler, RemovableChannelHandler {
    
    // MARK: - Types
    
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart
    
    // MARK: - Vars

    let logger: Logger
    let host: String
    let path: String
    let extraHeaders: [String: String]
    let onFailure: (ChannelHandlerContext, Error) -> Void
    
    private var upgradeResponseStatus: HTTPResponseStatus?
    private var upgradeResponseData: ByteBuffer = Allocator.shared.buffer(capacity: 0)
    
    // MARK: - Init

    init(
        logger: Logger,
        host: String,
        path: String,
        headers: [String: String],
        onFailure: @escaping (ChannelHandlerContext, Error) -> Void
    ) {
        self.logger = logger
        self.host = host
        self.path = path
        extraHeaders = headers
        self.onFailure = onFailure
    }
    
    // MARK: - ChannelInboundHandler
    
    func handlerAdded(context: ChannelHandlerContext) {
        // Start upgrade
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(0)")
        headers.add(name: "host", value: host)
        headers.add(name: "Sec-WebSocket-Protocol", value: "mqtt")
        extraHeaders.forEach { headers.add(name: $0, value: $1) }

        let head = HTTPRequestHead(
            version: HTTPVersion(major: 1, minor: 1),
            method: .GET,
            uri: path,
            headers: headers
        )
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        let emptyBuffer = context.channel.allocator.buffer(capacity: 0)
        let body = HTTPClientRequestPart.body(.byteBuffer(emptyBuffer))
        context.write(self.wrapOutboundOut(body), promise: nil)
        
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)

        switch response {
        case .head(let head):
            upgradeResponseStatus = head.status
            
        case .body(var body):
            upgradeResponseData.writeBuffer(&body)
            
        case .end:
            var data = upgradeResponseData
            let readableBytes = data.readableBytes
            let response = data.readString(length: readableBytes)
            logger.error("Failed to upgrade WebSocket", metadata: [
                "error": "Invalid response",
                "responseStatus": upgradeResponseStatus.map { "\($0)" } ?? "unknown",
                "response": .string(response ?? "\(readableBytes) bytes")
            ])
            
            onFailure(context, MQTTWebSocketError(
                responseStatus: upgradeResponseStatus,
                responseData: upgradeResponseData,
                underlyingError: nil
            ))
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Failed to upgrade WebSocket", metadata: [
            "error": "\(error)"
        ])
        
        onFailure(context, MQTTWebSocketError(
            responseStatus: nil,
            responseData: nil,
            underlyingError: error
        ))
    }
}
