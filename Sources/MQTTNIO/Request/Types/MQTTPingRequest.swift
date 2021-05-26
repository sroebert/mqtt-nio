import NIO
import Logging

final class MQTTPingRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let timeoutInterval: TimeAmount
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(timeoutInterval: TimeAmount) {
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        context.logger.debug("Sending: Ping Request")
        
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: timeoutInterval)
        
        context.write(MQTTPacket.PingReq())
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Void>? {
        guard case .pingResp = packet else {
            return nil
        }
        
        context.logger.debug("Received: Ping Response")
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .success
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .success(())
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Void> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Ping Response' in time")
        return .failure(Error.timeout)
    }
}
