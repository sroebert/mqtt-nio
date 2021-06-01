import NIO
import NIOHTTP1

/// An error that is returned when upgrading the web socket failed, while connecting to a broker using a web socket.
public struct MQTTWebSocketError: Error {
    
    /// The response status returned from the server, if available.
    public var responseStatus: HTTPResponseStatus?
    
    /// The response data returned from the server, if available.
    public var responseData: ByteBuffer?
    
    /// The underlying error returned from `NIO`, if available.
    public var underlyingError: Error?
}
