import Foundation
import NIO
import Logging

final class MQTTReAuthenticateRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case timeout
    }
    
    // MARK: - Vars
    
    let authenticationHandler: MQTTAuthenticationHandler
    let timeoutInterval: TimeAmount
    
    private var authenticationMethod: String?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(
        authenticationHandler: MQTTAuthenticationHandler,
        timeoutInterval: TimeAmount = .seconds(5)
    ) {
        self.authenticationHandler = authenticationHandler
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        
        authenticationMethod = authenticationHandler.authenticationMethod
        let authenticationData = authenticationHandler.initialAuthenticationData
        
        timeoutScheduled = context.scheduleEvent(Event.timeout, in: timeoutInterval)
        
        context.logger.debug("Sending: Auth (Re-Authetication)")
        context.write(MQTTPacket.Auth(
            reasonCode: .reAuthenticate,
            reasonString: nil,
            authenticationMethod: authenticationMethod,
            authenticationData: authenticationData?.byteBuffer
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Void>? {
        
        guard case .auth(let auth) = packet else {
            return nil
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        switch auth.reasonCode {
        case .success:
            return .success
            
        case .continueAuthentication:
            return handleContinuedAuth(for: auth, context: context)
            
        case .reAuthenticate:
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Received invalid re-authenticate reason for Auth packet"
            ))
        }
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .failure(MQTTConnectionError.connectionClosed)
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Void> {
        guard case Event.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Auth' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
    
    // MARK: - Utils
    
    private func handleContinuedAuth(
        for auth: MQTTPacket.Auth,
        context: MQTTRequestContext
    ) -> MQTTRequestResult<Void> {
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
            responseData = try authenticationHandler.processAuthenticationData(data)
        } catch {
            return .failure(error)
        }
        
        timeoutScheduled = context.scheduleEvent(Event.timeout, in: timeoutInterval)
        
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
