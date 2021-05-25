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
            "clean": .stringConvertible(configuration.clean),
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
        
        if let reason = connAck.serverErrorReason {
            context.logger.notice("Received: Connect Acknowledgement (Rejected)", metadata: [
                "returnCode": "\(connAck.returnCode)"
            ])
            
            return .failure(MQTTConnectionError.server(reason))
        }
        
        context.logger.debug("Received: Connect Acknowledgement (Accepted)")
        return .success(MQTTConnectResponse(
            isSessionPresent: connAck.isSessionPresent
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

extension MQTTPacket.ConnAck {
    fileprivate var serverErrorReason: MQTTConnectionError.ServerReason? {
        guard let code = returnCode.serverErrorReasonCode(
            with: properties
        ) else {
            return nil
        }
        return MQTTConnectionError.ServerReason(
            code: code,
            message: properties.reasonString
        )
    }
}

extension MQTTPacket.ConnAck.ReturnCode {
    fileprivate func serverErrorReasonCode(
        with properties: MQTTProperties
    ) -> MQTTConnectionError.ServerReason.Code? {
        switch self {
        case .version311(let returnCode):
            return returnCode.serverErrorReasonCode
            
        case .version5(let returnCode):
            return returnCode.serverErrorReasonCode(with: properties)
        }
    }
}

extension MQTTPacket.ConnAck.ReturnCode311 {
    fileprivate var serverErrorReasonCode: MQTTConnectionError.ServerReason.Code? {
        switch self {
        case .accepted: return nil
        case .unacceptableProtocolVersion: return .unsupportedProtocolVersion
        case .identifierRejected: return .invalidClientIdentifier
        case .serverUnavailable: return .serverUnavailable
        case .badUsernameOrPassword: return .badUsernameOrPassword
        case .notAuthorized: return .notAuthorized
        }
    }
}
    
extension MQTTPacket.ConnAck.ReturnCode5 {
    fileprivate func serverErrorReasonCode(
        with properties: MQTTProperties
    ) -> MQTTConnectionError.ServerReason.Code? {
        switch self {
        case .success: return nil
        case .unspecifiedError: return .unspecifiedError
        case .malformedPacket: return .malformedPacket
        case .protocolError: return .protocolError
        case .implementationSpecificError: return .implementationSpecificError
        case .unsupportedProtocolVersion: return .unsupportedProtocolVersion
        case .clientIdentifierNotValid: return .invalidClientIdentifier
        case .badUsernameOrPassword: return .badUsernameOrPassword
        case .notAuthorized: return .notAuthorized
        case .serverUnavailable: return .serverUnavailable
        case .serverBusy: return .serverBusy
        case .banned: return .banned
        case .badAuthenticationMethod: return .badAuthenticationMethod
        case .topicNameInvalid: return .invalidWillTopic
        case .packetTooLarge: return .packetTooLarge
        case .quotaExceeded: return .exceededQuota
        case .payloadFormatInvalid: return .invalidWillPayloadFormat
        case .retainNotSupported: return .willRetainNotSupported
        case .qosNotSupported: return .willQoSNotSupported
        case .useAnotherServer:
            return .useAnotherServer(properties.serverReference ?? "unknown")
        case .serverMoved:
            return .serverMoved(properties.serverReference ?? "unknown")
        case .connectionRateExceeded: return .exceededConnectionRate
        }
    }
}
