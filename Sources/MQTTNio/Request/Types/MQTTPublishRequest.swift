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
    
    func start(using idProvider: MQTTRequestIdProvider) throws -> MQTTRequestAction {
        let nextStatus: MQTTRequestAction.Status
        switch message.qos {
        case .atMostOnce:
            nextStatus = .success
            
        case .atLeastOnce, .exactlyOnce:
            nextStatus = .pending
            packetId = idProvider.getNextPacketId()
        }
        
        let publish = MQTTPacket.Publish(message: message, packetId: packetId)
        return .init(nextStatus: nextStatus, response: publish)
    }
    
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction {
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
                
                let response = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
                return .respond(response)
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
