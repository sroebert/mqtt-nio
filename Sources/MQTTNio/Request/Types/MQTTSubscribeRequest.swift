import NIO
import Logging

final class MQTTSubscribeRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let subscriptions: [MQTTSubscription]
    let timeoutInterval: TimeAmount
    
    private(set) var results: [MQTTSubscriptionResult] = []
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(subscriptions: [MQTTSubscription], timeoutInterval: TimeAmount = .seconds(5)) {
        self.subscriptions = subscriptions
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.write(MQTTPacket.Subscribe(
            subscriptions: subscriptions,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult {
        guard case .subAck(let subAck) = packet, subAck.packetId == packetId else {
            return .pending
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        guard subAck.results.count == subscriptions.count else {
            return .failure(MQTTConnectionError.protocol("Received an invalid number of subscription results."))
        }
        
        results = subAck.results
        return .success
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult {
        guard case Error.timeout = event else {
            return .pending
        }
        return .failure(MQTTConnectionError.protocol("Did not receive SubAck packet in time."))
    }
    
    func log(to logger: Logger) {
        let topics = subscriptions.map { $0.topic }.joined(separator: ",")
        logger.debug("Subscribing to: \(topics)")
    }
}
