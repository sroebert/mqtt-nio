import NIO
import Logging

final class MQTTDisconnectRequest: MQTTRequest {
    
    // MARK: - MQTTRequest
    
    var canPerformInInactiveState: Bool {
        return true
    }
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        context.logger.debug("Sending: Disconnect")
        
        let disconnect = MQTTPacket.Disconnect()
        context.write(disconnect)
        
        return .success(())
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        return .success(())
    }
}
