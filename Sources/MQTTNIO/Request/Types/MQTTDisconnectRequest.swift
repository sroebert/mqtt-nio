import NIO
import Logging

final class MQTTDisconnectRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let reasonCode: MQTTPacket.Disconnect.ReasonCode
    let reasonString: String?
    let sessionExpiry: MQTTConfiguration.SessionExpiry?
    let userProperties: [MQTTUserProperty]
    
    // MARK: - Init
    
    init?(reason: MQTTDisconnectReason) {
        switch reason {
        case .connectionClosed, .server:
            // In this case no disconnect message has to be send to the server
            return nil
            
        case .userInitiated(let userRequest):
            self.reasonCode = userRequest.sendWillMessage ? .disconnectWithWillMessage : .normalDisconnection
            self.reasonString = nil
            self.sessionExpiry = userRequest.sessionExpiry
            self.userProperties = userRequest.userProperties
            
        case .client(let protocolError):
            self.reasonCode = protocolError.code.disconnectReasonCode
            self.reasonString = protocolError.message
            self.sessionExpiry = nil
            self.userProperties = []
        }
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
