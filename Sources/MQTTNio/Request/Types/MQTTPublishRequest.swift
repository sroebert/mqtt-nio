import NIO
import Logging

final class MQTTPublishRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let message: MQTTMessage
    private let retryInterval: Double = 5
    
    private var acknowledgedPub: Bool = false
    private var packetId: UInt16?
    
    // MARK: - Init
    
    init(message: MQTTMessage) {
        self.message = message
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
            return .success
            
        case .exactlyOnce:
            if acknowledgement.kind == .pubRec {
                acknowledgedPub = true
                
                let pubRel = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
                context.write(pubRel)
                
                return .pending
            }
            
            guard acknowledgedPub && acknowledgement.kind == .pubComp else {
                return .pending
            }
            
            return .success
        }
    }
    
    func log(to logger: Logger) {
        logger.debug("Publishing \(message)")
    }
}
