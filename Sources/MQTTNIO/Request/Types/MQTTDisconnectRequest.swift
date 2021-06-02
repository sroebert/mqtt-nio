import NIO
import Logging

final class MQTTDisconnectRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case timeout
    }
    
    // MARK: - Vars
    
    let reasonCode: MQTTPacket.Disconnect.ReasonCode
    let reasonString: String?
    let sessionExpiry: MQTTConfiguration.SessionExpiry?
    let userProperties: [MQTTUserProperty]
    let timeoutInterval: TimeAmount
    
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init?(
        reason: MQTTDisconnectReason,
        timeoutInterval: TimeAmount = .seconds(2)
    ) {
        switch reason {
        case .connectionClosed, .server:
            // In this case no disconnect message has to be send to the server
            return nil
            
        case .userInitiated(let userRequest):
            self.reasonCode = userRequest.sendWillMessage ? .disconnectWithWillMessage : .normalDisconnection
            self.reasonString = nil
            self.sessionExpiry = userRequest.sessionExpiry
            self.userProperties = userRequest.userProperties
            self.timeoutInterval = timeoutInterval
            
        case .client(let protocolError):
            self.reasonCode = protocolError.code.disconnectReasonCode
            self.reasonString = protocolError.message
            self.sessionExpiry = nil
            self.userProperties = []
            self.timeoutInterval = timeoutInterval
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
        
        guard context.version >= .version5 else {
            return .success
        }
        
        timeoutScheduled = context.scheduleEvent(Event.timeout, in: timeoutInterval)
        return .pending
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .success
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Void> {
        guard case Event.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Broker did not close connection in time, disconnect manually")
        return .success
    }
}
