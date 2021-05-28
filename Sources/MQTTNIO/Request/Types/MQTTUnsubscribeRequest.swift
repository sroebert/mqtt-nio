import NIO
import Logging

final class MQTTUnsubscribeRequest: MQTTRequest {
    
    // MARK: - Types
    
    private enum Event {
        case timeout
    }
    
    // MARK: - Vars
    
    let topicFilters: [String]
    let userProperties: [MQTTUserProperty]
    let timeoutInterval: TimeAmount
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(
        topicFilters: [String],
        userProperties: [MQTTUserProperty],
        timeoutInterval: TimeAmount = .seconds(5)
    ) {
        self.topicFilters = topicFilters
        self.userProperties = userProperties
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<MQTTUnsubscribeResponse> {
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        let packet = MQTTPacket.Unsubscribe(
            topicFilters: topicFilters,
            userProperties: userProperties,
            packetId: packetId
        )
        
        if let error = error(for: packet, context: context) {
            return .failure(error)
        }
        
        timeoutScheduled = context.scheduleEvent(Event.timeout, in: timeoutInterval)
        
        context.logger.debug("Sending: Unsubscribe", metadata: [
            "packetId": .stringConvertible(packetId),
            "topicFilters": .array(topicFilters.map { .string($0) })
        ])
        
        context.write(packet)
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<MQTTUnsubscribeResponse>? {
        guard case .unsubAck(let unsubAck) = packet, unsubAck.packetId == packetId else {
            return nil
        }
        
        let results = unsubAck.results ?? .init(repeating: .success, count: topicFilters.count)
        
        guard results.count == topicFilters.count else {
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Received an invalid number of unsubscribe results."
            ))
        }
        
        context.logger.debug("Received: Unsubscribe Acknowledgement", metadata: [
            "packetId": .stringConvertible(unsubAck.packetId),
            "results": .array(results.map { result in
                switch result {
                case .success:
                    return [
                        "unsubscribed": .stringConvertible(true),
                    ]
                case .failure(let reason):
                    return [
                        "unsubscribed": .stringConvertible(false),
                        "reason": .string("\(reason)")
                    ]
                }
            })
        ])
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil

        let response = MQTTUnsubscribeResponse(
            results: results,
            userProperties: unsubAck.properties.userProperties,
            reasonString: unsubAck.properties.reasonString
        )
        return .success(response)
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<MQTTUnsubscribeResponse> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .failure(MQTTConnectionError.connectionClosed)
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<MQTTUnsubscribeResponse> {
        guard case Event.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Unsubscribe Acknowledgement' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
    
    // MARK: - Utils
    
    private func error(for packet: MQTTPacket.Unsubscribe, context: MQTTRequestContext) -> Error? {
        if let maximumPacketSize = context.brokerConfiguration.maximumPacketSize {
            let size = packet.size(version: context.version)
            guard size <= maximumPacketSize else {
                return MQTTProtocolError(
                    code: .packetTooLarge,
                    "The size of the packet exceeds the maximum packet size of the broker."
                )
            }
        }
        
        return nil
    }
}
