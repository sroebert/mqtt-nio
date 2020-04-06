public protocol MQTTListenerContext {
    func stopListening()
}

public struct MQTTConnectResponse {
    public var isSessionPresent: Bool
    public var returnCode: ReturnCode
    
    public enum ReturnCode {
        case accepted
        case unacceptableProtocolVersion
        case identifierRejected
        case serverUnavailable
        case badUsernameOrPassword
        case notAuthorized
    }
}

public enum MQTTDisconnectReason {
    case userInitiated
    case connectionClosed
    case error(Error)
}

public typealias MQTTConnectListener = (_ client: MQTTClient, _ response: MQTTConnectResponse, _ context: MQTTListenerContext) -> Void
public typealias MQTTDisconnectListener = (_ client: MQTTClient, _ reason: MQTTDisconnectReason, _ context: MQTTListenerContext) -> Void

public typealias MQTTErrorListener = (_ client: MQTTClient, _ error: Error, _ context: MQTTListenerContext) -> Void

public typealias MQTTMessageListener = (_ client: MQTTClient, _ message: MQTTMessage, _ context: MQTTListenerContext) -> Void

extension CallbackList.Entry : MQTTListenerContext {
    func stopListening() {
        remove()
    }
}
