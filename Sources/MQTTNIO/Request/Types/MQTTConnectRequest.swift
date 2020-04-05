import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Types
    
    struct Response {
        var isSessionPresent: Bool
    }
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let configuration: MQTTConfiguration
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(configuration: MQTTConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - MQTTRequest
    
    var canPerformInInactiveState: Bool {
        return true
    }
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Response> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: configuration.connectTimeoutInterval)
        
        context.logger.debug("Sending: Connect", metadata: [
            "clientId": .string(configuration.clientId),
            "cleanSession": .stringConvertible(configuration.cleanSession),
        ])
        
        context.write(MQTTPacket.Connect(configuration: configuration))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Response> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        guard case .connAck(let connAck) = packet else {
            let error = MQTTConnectionError.protocol("Received invalid packet after sending connect: \(packet)")
            return .failure(error)
        }
        
        switch connAck.returnCode {
        case .accepted:
            context.logger.debug("Received: Connect Acknowledgement (Accepted)")
            
        default:
            context.logger.notice("Received: Connect Acknowledgement (Rejected)", metadata: [
                "returnCode": "\(connAck.returnCode)"
            ])
        }
        
        switch connAck.returnCode {
        case .accepted:
            let response = Response(isSessionPresent: connAck.isSessionPresent)
            return .success(response)
            
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
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Response> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Connect Acknowledgement' in time")
        return .failure(MQTTConnectionError.protocol("Did not receive ConnAck packet in time."))
    }
}
