import NIO
import Logging

final class MQTTUnsubscribeRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let topics: [String]
    let userProperties: [MQTTUserProperty]
    let timeoutInterval: TimeAmount
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(
        topics: [String],
        userProperties: [MQTTUserProperty],
        timeoutInterval: TimeAmount = .seconds(5)
    ) {
        self.topics = topics
        self.userProperties = userProperties
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<MQTTUnsubscribeResponse> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.logger.debug("Sending: Unsubscribe", metadata: [
            "packetId": .stringConvertible(packetId),
            "topics": .array(topics.map { .string($0) })
        ])
        
        context.write(MQTTPacket.Unsubscribe(
            topics: topics,
            userProperties: userProperties,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<MQTTUnsubscribeResponse>? {
        guard case .unsubAck(let unsubAck) = packet, unsubAck.packetId == packetId else {
            return nil
        }
        
        let results = unsubAck.results ?? .init(repeating: .success, count: topics.count)
        
        guard results.count == topics.count else {
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
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Unsubscribe Acknowledgement' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
}
