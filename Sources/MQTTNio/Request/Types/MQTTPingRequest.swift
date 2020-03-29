import NIO
import Logging

final class MQTTPingRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Init
    
    let keepAliveInterval: TimeAmount
    
    // MARK: - Init
    
    init(keepAliveInterval: TimeAmount) {
        self.keepAliveInterval = keepAliveInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        context.scheduleEvent(Error.timeout, in: keepAliveInterval)
        
        context.write(MQTTPacket.PingReq())
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        guard case .pingResp = packet else {
            return .pending
        }
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
