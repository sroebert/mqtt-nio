import NIO
import Logging

final class MQTTDisconnectRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let reasonCode: MQTTPacket.Disconnect.ReasonCode
    let reasonString: String?
    let sessionExpiry: MQTTConfiguration.SessionExpiry
    let userProperties: [MQTTUserProperty]
    
    // MARK: - Init
    
    init(
        reasonCode: MQTTPacket.Disconnect.ReasonCode = .normalDisconnection,
        reasonString: String? = nil,
        sessionExpiry: MQTTConfiguration.SessionExpiry,
        userProperties: [MQTTUserProperty] = []
    ) {
        self.reasonCode = reasonCode
        self.reasonString = reasonString
        self.sessionExpiry = sessionExpiry
        self.userProperties = userProperties
    }
    
    // MARK: - MQTTRequest
    
    var canPerformInInactiveState: Bool {
        return true
    }
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        context.logger.debug("Sending: Disconnect")
        
        let disconnect = MQTTPacket.Disconnect(
            reasonCode: reasonCode,
            reasonString: reasonString,
            sessionExpiry: sessionExpiry,
            userProperties: userProperties
        )
        context.write(disconnect)
        
        return .success(())
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        return .success(())
    }
}
