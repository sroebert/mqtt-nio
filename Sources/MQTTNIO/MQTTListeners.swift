public protocol MQTTListenerContext {
    func stopListening()
}

public struct MQTTConnectResponse {
    public var isSessionPresent: Bool
    
    init(_ response: MQTTConnectRequest.Response) {
        isSessionPresent = response.isSessionPresent
    }
}

public typealias MQTTConnectListener = (_ response: MQTTConnectResponse, _ context: MQTTListenerContext) -> Void

public typealias MQTTMessageListener = (_ message: MQTTMessage, _ context: MQTTListenerContext) -> Void

extension CallbackList.Entry : MQTTListenerContext {
    func stopListening() {
        remove()
    }
}
