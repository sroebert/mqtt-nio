import NIO
import Logging

final class MQTTUnsubscribeRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let topics: [String]
    let timeoutInterval: TimeAmount
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(topics: [String], timeoutInterval: TimeAmount = .seconds(5)) {
        self.topics = topics
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<Void> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.logger.debug("Sending: Unsubscribe", metadata: [
            "packetId": .stringConvertible(packetId),
            "topics": .array(topics.map { .string($0) })
        ])
        
        context.write(MQTTPacket.Unsubscribe(
            topics: topics,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<Void> {
        guard case .unsubAck(let unsubAck) = packet, unsubAck.packetId == packetId else {
            return .pending
        }
        
        context.logger.debug("Received: Unsubscribe Acknowledgement", metadata: [
            "packetId": .stringConvertible(unsubAck.packetId),
        ])
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil

        return .success
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<()> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .failure(MQTTConnectionError.protocol("Disconnected while trying to unsubscribe"))
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<Void> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Unsubscribe Acknowledgement' in time")
        return .failure(MQTTConnectionError.protocol("Did not receive UnsubAck packet in time."))
    }
}
