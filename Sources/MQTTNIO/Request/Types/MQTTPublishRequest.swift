import NIO
import Logging

final class MQTTPublishRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case retry
    }
    
    // MARK: - Vars
    
    let message: MQTTMessage
    let retryInterval: TimeAmount?
    
    private var acknowledgedPub: Bool = false
    private var packetId: UInt16?
    
    private var scheduledRetry: Scheduled<Void>?
    
    // MARK: - Init
    
    init(message: MQTTMessage, retryInterval: TimeAmount?) {
        self.message = message
        self.retryInterval = retryInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        let result: MQTTRequestResult<Void>
        switch message.qos {
        case .atMostOnce:
            result = .success
            
        case .atLeastOnce, .exactlyOnce:
            result = .pending
            packetId = context.getNextPacketId()
            
            scheduleRetry(context: context)
        }
        
        context.logger.debug("Sending: Publish", metadata: [
            "packetId": .string(packetId.map { $0.description } ?? "none"),
            "topic": .string(message.topic),
            "payload": .string(message.payload.debugDescription),
            "qos": .stringConvertible(message.qos.rawValue),
            "retain": .stringConvertible(message.retain)
        ])
        
        context.write(MQTTPacket.Publish(message: message, packetId: packetId))
        return result
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Void>? {
        guard case .acknowledgement(let acknowledgement) = packet, acknowledgement.packetId == packetId else {
            return nil
        }
        
        let packetId = acknowledgement.packetId
        
        switch message.qos {
        case .atMostOnce:
            // Should never happen, as the request already finished at the start.
            return nil
            
        case .atLeastOnce:
            guard acknowledgement.kind == .pubAck else {
                // We received an unknown acknowledgement, ignore
                return nil
            }
            
            context.logger.debug("Received: Publish Acknowledgement", metadata: [
                "packetId": .stringConvertible(acknowledgement.packetId),
            ])
            
            cancelRetry()
            return result(for: acknowledgement, context: context)
            
        case .exactlyOnce:
            if acknowledgement.kind == .pubRec {
                acknowledgedPub = true
                cancelRetry()
                
                // If the server returned a failure reason, fail the request.
                if case .failure(let error) = result(for: acknowledgement, context: context) {
                    return .failure(error)
                }
                
                context.logger.debug("Received: Publish Received", metadata: [
                    "packetId": .stringConvertible(acknowledgement.packetId),
                ])
                
                context.logger.debug("Sending: Publish Release", metadata: [
                    "packetId": .stringConvertible(acknowledgement.packetId),
                ])
                
                let pubRel = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
                context.write(pubRel)
                scheduleRetry(context: context)
                
                return .pending
            }
            
            guard acknowledgedPub && acknowledgement.kind == .pubComp else {
                // We received an unknown acknowledgement, ignore
                return nil
            }
            
            context.logger.debug("Received: Publish Complete", metadata: [
                "packetId": .stringConvertible(acknowledgement.packetId),
            ])
            
            cancelRetry()
            return result(for: acknowledgement, context: context)
        }
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Void> {
        if scheduledRetry != nil, case Event.retry = event {
            retry(context: context)
        }
        return .pending
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        cancelRetry()
        return .pending
    }
    
    func connected(context: MQTTRequestContext, isSessionPresent: Bool) -> MQTTRequestResult<Void> {
        if !isSessionPresent && acknowledgedPub {
            return .failure(MQTTPublishError.sessionCleared)
        }
        
        retry(context: context)
        return .pending
    }
    
    // MARK: - Utils
    
    private func scheduleRetry(context: MQTTRequestContext) {
        cancelRetry()
        
        guard
            let retryInterval = retryInterval,
            retryInterval.nanoseconds > 0
        else {
            return
        }
        
        context.scheduleEvent(Event.retry, in: retryInterval)
    }
    
    private func cancelRetry() {
        scheduledRetry?.cancel()
        scheduledRetry = nil
    }
    
    private func retry(context: MQTTRequestContext) {
        guard let packetId = packetId else {
            return
        }
        
        switch (message.qos, acknowledgedPub) {
        case (.atLeastOnce, _), (.exactlyOnce, false):
            let publish = MQTTPacket.Publish(
                message: message,
                packetId: packetId,
                isDuplicate: true
            )
            context.write(publish)
            
        case (.exactlyOnce, true):
            let pubRel = MQTTPacket.Acknowledgement(kind: .pubRel, packetId: packetId)
            context.write(pubRel)
            
        default:
            break
        }
    }
    
    private func result(
        for acknowledgement: MQTTPacket.Acknowledgement,
        context: MQTTRequestContext
    ) -> MQTTRequestResult<Void> {
        if let errorReason = acknowledgement.serverErrorReason {
            context.logger.notice("Received: \(acknowledgement.kind) (Rejected)", metadata: [
                "packetId": .stringConvertible(acknowledgement.packetId),
                "reasonCode": "\(acknowledgement.reasonCode)"
            ])
            
            return .failure(MQTTPublishError.server(errorReason))
        }
        
        return .success
    }
}

extension MQTTPacket.Acknowledgement {
    fileprivate var serverErrorReason: MQTTPublishError.ServerReason? {
        guard let code = reasonCode.serverErrorReasonCode else {
            return nil
        }
        return MQTTPublishError.ServerReason(
            code: code,
            message: reasonString
        )
    }
}

extension MQTTPacket.Acknowledgement.ReasonCode {
    fileprivate var serverErrorReasonCode: MQTTPublishError.ServerReason.Code? {
        switch self {
        case .success: return nil
        case .noMatchingSubscribers: return nil
        case .unspecifiedError: return .unspecifiedError
        case .implementationSpecificError: return .implementationSpecificError
        case .notAuthorized: return .notAuthorized
        case .topicNameInvalid: return .topicNameInvalid
        case .packetIdentifierInUse: return .packetIdentifierInUse
        case .packetIdentifierNotFound: return nil
        case .quotaExceeded: return .quotaExceeded
        case .payloadFormatInvalid: return .payloadFormatInvalid
        }
    }
}
