import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Vars
    
    let config: MQTTConnection.ConnectConfig
    
    // MARK: - Init
    
    init(config: MQTTConnection.ConnectConfig) {
        self.config = config
    }
    
    // MARK: - MQTTRequest
    
    func start(using idProvider: MQTTRequestIdProvider) throws -> MQTTRequestAction {
        return .init(response: MQTTPacket.Connect(config: config))
    }
    
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction {
        guard case .connAck(let connAck) = packet else {
            let error = MQTTConnectionError.protocol("Received invalid packet after sending connect: \(packet)")
            return .failure(error)
        }
        
        switch connAck.returnCode {
        case .accepted:
            return .success
            
        case .unacceptableProtocolVersion:
            return .failure(MQTTServerError.unacceptableProtocolVersion)
        case .identifierRejected:
            return .failure(MQTTServerError.identifierRejected)
        case .serverUnavailable:
            return .failure(MQTTServerError.serverUnavailable)
        case .badUsernameOrPassword:
            return .failure(MQTTServerError.badUsernameOrPassword)
        case .notAuthorized:
            return .failure(MQTTServerError.notAuthorized)
            
        default:
            return .failure(MQTTServerError.unknown)
        }
    }
    
    func log(to logger: Logger) {
        logger.debug("Establishing connection with MQTT server")
    }
}
