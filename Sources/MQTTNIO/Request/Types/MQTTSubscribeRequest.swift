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
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(subscriptions: [MQTTSubscription], timeoutInterval: TimeAmount = .seconds(5)) {
        self.subscriptions = subscriptions
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<[MQTTSubscriptionResult]> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.logger.debug("Sending: Subscribe", metadata: [
            "packetId": .stringConvertible(packetId),
            "subscriptions": .array(subscriptions.map { [
                "topic": .string($0.topic),
                "qos": .stringConvertible($0.qos.rawValue)
            ] })
        ])
        
        context.write(MQTTPacket.Subscribe(
            subscriptions: subscriptions,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<[MQTTSubscriptionResult]> {
        guard case .subAck(let subAck) = packet, subAck.packetId == packetId else {
            return .pending
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        guard subAck.results.count == subscriptions.count else {
            return .failure(MQTTConnectionError.protocol("Received an invalid number of subscription results."))
        }
        
        context.logger.debug("Received: Subscribe Acknowledgement", metadata: [
            "packetId": .stringConvertible(subAck.packetId),
            "results": .array(subAck.results.map { result in
                switch result {
                case .success(let qos):
                    return [
                        "accepted": .stringConvertible(true),
                        "qos": .stringConvertible(qos.rawValue)
                    ]
                case .failure:
                    return [
                        "accepted": .stringConvertible(false)
                    ]
                }
            })
        ])
        
        return .success(subAck.results)
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<Array<MQTTSubscriptionResult>> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .failure(MQTTConnectionError.protocol("Disconnected while trying to subscribe"))
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<[MQTTSubscriptionResult]> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Subscription Acknowledgement' in time")
        return .failure(MQTTConnectionError.protocol("Did not receive SubAck packet in time."))
    }
}
