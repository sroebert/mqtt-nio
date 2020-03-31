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
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: timeoutInterval)
        
        context.write(MQTTPacket.PingReq())
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        guard case .pingResp = packet else {
            return .pending
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .success
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        guard case Error.timeout = event else {
            return .pending
        }
        return .failure(Error.timeout)
    }
    
    func log(to logger: Logger) {
        logger.debug("Pinging the server")
    }
}
