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
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.write(MQTTPacket.Unsubscribe(
            topics: topics,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        guard case .unsubAck(let unsubAck) = packet, unsubAck.packetId == packetId else {
            return .pending
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil

        return .success
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        guard case Error.timeout = event else {
            return .pending
        }
        return .failure(MQTTConnectionError.protocol("Did not receive UnsubAck packet in time."))
    }
    
    func log(to logger: Logger) {
        logger.debug("Unsubscribing from: \(topics.joined(separator: ", "))")
    }
}
