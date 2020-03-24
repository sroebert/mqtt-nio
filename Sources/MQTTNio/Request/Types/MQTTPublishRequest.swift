import NIO
import Logging

final class MQTTPublishRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let message: MQTTMessage
    
    // MARK: - Init
    
    init(message: MQTTMessage) {
        self.message = message
    }
    
    // MARK: - MQTTRequest
    
    func start() throws -> MQTTRequestAction {
        return .init(nextStatus: .success, response: MQTTPacket.Publish(message: message))
    }
    
    func shouldProcess(_ packet: MQTTPacket.Inbound) -> Bool {
        return false
    }
    
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction {
        fatalError()
    }
    
    func log(to logger: Logger) {
        logger.debug("Publishing \(message)")
    }
}
