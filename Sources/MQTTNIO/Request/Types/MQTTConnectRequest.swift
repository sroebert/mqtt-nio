import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Types
    
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
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<MQTTConnectResponse> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: configuration.connectRequestTimeoutInterval)
        
        context.logger.debug("Sending: Connect", metadata: [
            "clientId": .string(configuration.clientId),
            "cleanSession": .stringConvertible(configuration.cleanSession),
        ])
        
        context.write(MQTTPacket.Connect(configuration: configuration))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<MQTTConnectResponse> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        guard case .connAck(let connAck) = packet else {
            let error = MQTTProtocolError.parsingError("Received invalid packet after sending Connect: \(packet)")
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
        
        return .success(MQTTConnectResponse(
            isSessionPresent: connAck.isSessionPresent,
            returnCode: connAck.returnCode.connectResponseReturnCode
        ))
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<MQTTConnectResponse> {
        context.logger.notice("Disconnected while waiting for 'Connect Acknowledgement'")
        return .failure(MQTTConnectionError.connectionClosed)
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<MQTTConnectResponse> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Connect Acknowledgement' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
}

extension MQTTPacket.ConnAck.ReturnCode {
    fileprivate var connectResponseReturnCode: MQTTConnectResponse.ReturnCode {
        switch self {
        case .accepted: return .accepted
        case .unacceptableProtocolVersion: return .unacceptableProtocolVersion
        case .identifierRejected: return .identifierRejected
        case .serverUnavailable: return .serverUnavailable
        case .badUsernameOrPassword: return .badUsernameOrPassword
        case .notAuthorized: return .notAuthorized
        }
    }
}
