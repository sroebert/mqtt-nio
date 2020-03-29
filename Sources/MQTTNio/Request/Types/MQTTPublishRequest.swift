import NIO
import Logging

final class MQTTPublishRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case retry
    }
    
    // MARK: - Vars
    
    let message: MQTTMessage
    let retryInterval: TimeAmount
    
    private var acknowledgedPub: Bool = false
    private var packetId: UInt16?
    
    private var scheduledRetry: Scheduled<Void>?
    
    // MARK: - Init
    
    init(message: MQTTMessage, retryInterval: TimeAmount = .seconds(5)) {
        self.message = message
        self.retryInterval = retryInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        let result: MQTTRequestResult
        switch message.qos {
        case .atMostOnce:
            result = .success
            
        case .atLeastOnce, .exactlyOnce:
            result = .pending
            packetId = context.getNextPacketId()
            
            scheduleRetry(context: context)
        }
        
        context.write(MQTTPacket.Publish(message: message, packetId: packetId))
        return result
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        guard case .acknowledgement(let acknowledgement) = packet, acknowledgement.packetId == packetId else {
            return .pending
        }
        
        let packetId = acknowledgement.packetId
        
        switch message.qos {
        case .atMostOnce:
            return .pending
            
        case .atLeastOnce:
            guard acknowledgement.kind == .pubAck else {
                return .pending
            }
            cancelRetry()
            return .success
            
        case .exactlyOnce:
            if acknowledgement.kind == .pubRec {
                acknowledgedPub = true
                cancelRetry()
                
                let pubRel = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
                context.write(pubRel)
                scheduleRetry(context: context)
                
                return .pending
            }
            
            guard acknowledgedPub && acknowledgement.kind == .pubComp else {
                return .pending
            }
            
            cancelRetry()
            return .success
        }
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        if scheduledRetry != nil, case Event.retry = event {
            retry(context: context)
        }
        return .pending
    }
    
    func resume(context: MQTTRequestContext) -> MQTTRequestResult {
        retry(context: context)
        return .pending
    }
    
    func pause(context: MQTTRequestContext) {
        cancelRetry()
    }
    
    func log(to logger: Logger) {
        logger.debug("Publishing \(message)")
    }
    
    // MARK: - Utils
    
    private func scheduleRetry(context: MQTTRequestContext) {
        cancelRetry()
        
        guard retryInterval.nanoseconds > 0 else {
            return
        }
        
        context.scheduleEvent(Event.retry, in: retryInterval)
    }
    
    private func cancelRetry() {
        scheduledRetry?.cancel()
        scheduledRetry = nil
    }
    
    private func retry(context: MQTTRequestContext) {
        guard let packetId = packetId else {
            return
        }
        
        switch (message.qos, acknowledgedPub) {
        case (.atLeastOnce, _), (.exactlyOnce, false):
            let publish = MQTTPacket.Publish(
                message: message,
                packetId: packetId,
                isDuplicate: true
            )
            context.write(publish)
            
        case (.exactlyOnce, true):
            let pubRel = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
            context.write(pubRel)
            
        default:
            break
        }
    }
}
