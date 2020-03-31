import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let configuration: MQTTConnectionConfiguration
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(configuration: MQTTConnectionConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: configuration.connectTimeoutInterval)
        
        context.write(MQTTPacket.Connect(configuration: configuration))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
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
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        guard case Error.timeout = event else {
            return .pending
        }
        return .failure(MQTTConnectionError.protocol("Did not receive ConnAck packet in time."))
    }
    
    func log(to logger: Logger) {
        logger.debug("Establishing connection with MQTT server")
    }
}
