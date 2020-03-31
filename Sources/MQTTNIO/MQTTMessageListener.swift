public typealias MQTTMessageListener = (MQTTMessageListenContext, MQTTMessage) -> Void

public final class MQTTMessageListenContext {
    var stopper: (() -> Void)?
    
    public func stop() {
        stopper?()
        stopper = nil
    }
}
