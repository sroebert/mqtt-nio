import NIO
import Logging

protocol MQTTRequestContext {
    func write(_ outbound: MQTTPacket.Outbound)
    
    func getNextPacketId() -> UInt16
    
    @discardableResult
    func scheduleEvent(_ event: Any, in time: TimeAmount) -> Scheduled<Void>
}

protocol MQTTRequest {
    func start(context: MQTTRequestContext) -> MQTTRequestResult
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult
    
    func pause(context: MQTTRequestContext)
    func resume(context: MQTTRequestContext) -> MQTTRequestResult
    
    func log(to logger: Logger)
}

extension MQTTRequest {
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) throws -> MQTTRequestResult {
        return .pending
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        return .pending
    }
    
    func pause(context: MQTTRequestContext) {
        
    }
    
    func resume(context: MQTTRequestContext) -> MQTTRequestResult {
        return .pending
    }
}

enum MQTTRequestResult {
    case pending
    case success
    case failure(Error)
}
