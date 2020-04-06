import NIO
import Logging

protocol MQTTRequestContext {
    var logger: Logger { get }
    
    func write(_ outbound: MQTTPacket.Outbound)
    
    func getNextPacketId() -> UInt16
    
    @discardableResult
    func scheduleEvent(_ event: Any, in time: TimeAmount) -> Scheduled<Void>
}

protocol MQTTRequest {
    associatedtype Value
    
    var canPerformInInactiveState: Bool { get }
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Value>
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Value>
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Value>
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Value>
    func connected(context: MQTTRequestContext, isSessionPresent: Bool) -> MQTTRequestResult<Value>
}

extension MQTTRequest {
    var canPerformInInactiveState: Bool {
        return false
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Value> {
        return .pending
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Value> {
        return .pending
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Value> {
        return .pending
    }
    
    func connected(context: MQTTRequestContext, isSessionPresent: Bool) -> MQTTRequestResult<Value> {
        return .pending
    }
}

enum MQTTRequestResult<Value> {
    case pending
    case success(Value)
    case failure(Error)
    
    var promiseResult: Result<Value, Error>? {
        switch self {
        case .pending:
            return nil
            
        case .success(let value):
            return .success(value)
            
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension MQTTRequestResult where Value == Void {
    static let success: MQTTRequestResult<Value> = .success(())
}
