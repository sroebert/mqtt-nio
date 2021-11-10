import Foundation
import NIO
import Logging

final class MQTTConnectRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case timeout
    }
    
    // MARK: - Vars
    
    let configuration: MQTTConfiguration
    
    private var timeoutScheduled: Scheduled<Void>?
    
    private var authenticationHandler: MQTTAuthenticationHandler?
    private var authenticationMethod: String?
    
    // MARK: - Init
    
    init(configuration: MQTTConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - MQTTRequest
    
    var canPerformInInactiveState: Bool {
        return true
    }
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<MQTTPacket.ConnAck> {
        timeoutScheduled = context.scheduleEvent(Event.timeout, in: configuration.connectRequestTimeoutInterval)
        
        context.logger.debug("Sending: Connect", metadata: [
            "clientId": .string(configuration.clientId),
            "clean": .stringConvertible(configuration.clean),
        ])
        
        authenticationHandler = configuration.authenticationHandlerProvider()
        authenticationMethod = authenticationHandler?.authenticationMethod
        let authenticationData = authenticationHandler?.initialAuthenticationData
        
        context.write(MQTTPacket.Connect(
            configuration: configuration,
            authenticationMethod: authenticationMethod,
            authenticationData: authenticationData?.byteBuffer
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<MQTTPacket.ConnAck>? {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        switch packet {
        case .connAck(let connAck):
            return handle(connAck, context: context)
            
        case .auth(let auth):
            return handle(auth, context: context)
            
        default:
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Received invalid packet in the Connect process: \(packet)"
            ))
        }
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<MQTTPacket.ConnAck> {
        context.logger.notice("Disconnected while waiting for 'Connect Acknowledgement'")
        return .failure(MQTTConnectionError.connectionClosed)
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<MQTTPacket.ConnAck> {
        guard case Event.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Connect Acknowledgement' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
    
    // MARK: - Utils
    
    private func handle(
        _ connAck: MQTTPacket.ConnAck,
        context: MQTTRequestContext
    ) -> MQTTRequestResult<MQTTPacket.ConnAck> {
        if let errorReason = connAck.serverErrorReason {
            context.logger.notice("Received: Connect Acknowledgement (Rejected)", metadata: [
                "reasonCode": "\(connAck.reasonCode)"
            ])
            return .failure(MQTTConnectionError.server(errorReason))
        }
        
        context.logger.debug("Received: Connect Acknowledgement (Accepted)")
        return .success(connAck)
    }
    
    private func handle(
        _ auth: MQTTPacket.Auth,
        context: MQTTRequestContext
    ) -> MQTTRequestResult<MQTTPacket.ConnAck> {
        guard let handler = authenticationHandler else {
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Received unexpected auth packet in the Connect process"
            ))
        }
        
        guard auth.authenticationMethod == authenticationMethod else {
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Invalid authentication method received from the broker: \(auth.authenticationMethod ?? "nil")"
            ))
        }
        
        context.logger.debug("Received: Auth")
        
        let data = auth.authenticationData.map { Data($0.readableBytesView) }
        let responseData: Data?
        do {
            responseData = try handler.processAuthenticationData(data)
        } catch {
            return .failure(error)
        }
        
        context.logger.debug("Sending: Auth")
        
        context.write(MQTTPacket.Auth(
            reasonCode: .continueAuthentication,
            reasonString: nil,
            authenticationMethod: authenticationMethod,
            authenticationData: responseData?.byteBuffer
        ))
        return .pending
    }
}

extension MQTTPacket.ConnAck {
    fileprivate var serverErrorReason: MQTTConnectionError.ServerReason? {
        guard let code = reasonCode.serverErrorReasonCode(
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

extension MQTTPacket.ConnAck.ReasonCode {
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

extension MQTTPacket.ConnAck.ReasonCode311 {
    fileprivate var serverErrorReasonCode: MQTTConnectionError.ServerReason.Code? {
        switch self {
        case .accepted: return nil
        case .unacceptableProtocolVersion: return .unsupportedProtocolVersion
        case .identifierRejected: return .clientIdentifierNotValid
        case .serverUnavailable: return .serverUnavailable
        case .badUsernameOrPassword: return .badUsernameOrPassword
        case .notAuthorized: return .notAuthorized
        }
    }
}
    
extension MQTTPacket.ConnAck.ReasonCode5 {
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
        case .clientIdentifierNotValid: return .clientIdentifierNotValid
        case .badUsernameOrPassword: return .badUsernameOrPassword
        case .notAuthorized: return .notAuthorized
        case .serverUnavailable: return .serverUnavailable
        case .serverBusy: return .serverBusy
        case .banned: return .banned
        case .badAuthenticationMethod: return .badAuthenticationMethod
        case .topicNameInvalid: return .topicNameInvalid
        case .packetTooLarge: return .packetTooLarge
        case .quotaExceeded: return .quotaExceeded
        case .payloadFormatInvalid: return .payloadFormatInvalid
        case .retainNotSupported: return .retainNotSupported
        case .qosNotSupported: return .qosNotSupported
        case .useAnotherServer: return .useAnotherServer(properties.serverReference)
        case .serverMoved: return .serverMoved(properties.serverReference)
        case .connectionRateExceeded: return .connectionRateExceeded
        }
    }
}
