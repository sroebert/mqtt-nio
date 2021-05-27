import NIO
import Logging

final class MQTTSubscribeRequest: MQTTRequest {
    
    // MARK: - Types
    
    enum Error: Swift.Error {
        case timeout
    }
    
    // MARK: - Vars
    
    let subscriptions: [MQTTSubscription]
    let subscriptionIdentifier: Int?
    let userProperties: [MQTTUserProperty]
    let timeoutInterval: TimeAmount
    
    private var packetId: UInt16?
    private var timeoutScheduled: Scheduled<Void>?
    
    // MARK: - Init
    
    init(
        subscriptions: [MQTTSubscription],
        subscriptionIdentifier: Int?,
        userProperties: [MQTTUserProperty],
        timeoutInterval: TimeAmount = .seconds(5)
    ) {
        self.subscriptions = subscriptions
        self.subscriptionIdentifier = subscriptionIdentifier
        self.userProperties = userProperties
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - MQTTRequest
    
    func start(context: MQTTRequestContext) -> MQTTRequestResult<MQTTSubscribeResponse> {
        timeoutScheduled = context.scheduleEvent(Error.timeout, in: .seconds(5))
        
        let packetId = context.getNextPacketId()
        self.packetId = packetId
        
        context.logger.debug("Sending: Subscribe", metadata: [
            "packetId": .stringConvertible(packetId),
            "subscriptions": .array(subscriptions.map { [
                "topicFilter": .string($0.topicFilter),
                "qos": .stringConvertible($0.qos.rawValue)
            ] })
        ])
        
        context.write(MQTTPacket.Subscribe(
            subscriptions: subscriptions,
            subscriptionIdentifier: subscriptionIdentifier,
            userProperties: userProperties,
            packetId: packetId
        ))
        return .pending
    }
    
    func process(context: MQTTRequestContext, packet: MQTTPacket.Inbound) -> MQTTRequestResult<MQTTSubscribeResponse>? {
        guard case .subAck(let subAck) = packet, subAck.packetId == packetId else {
            return nil
        }
        
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        guard subAck.results.count == subscriptions.count else {
            return .failure(MQTTProtocolError(
                code: .protocolError,
                "Received an invalid number of subscription results."
            ))
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
                case .failure(let reason):
                    return [
                        "accepted": .stringConvertible(false),
                        "reason": .string("\(reason)")
                    ]
                }
            })
        ])
        
        let response = MQTTSubscribeResponse(
            results: subAck.results,
            userProperties: subAck.properties.userProperties,
            reasonString: subAck.properties.reasonString
        )
        return .success(response)
    }
    
    func disconnected(context: MQTTRequestContext) -> MQTTRequestResult<MQTTSubscribeResponse> {
        timeoutScheduled?.cancel()
        timeoutScheduled = nil
        
        return .failure(MQTTConnectionError.connectionClosed)
    }
    
    func handleEvent(context: MQTTRequestContext, event: Any) -> MQTTRequestResult<MQTTSubscribeResponse> {
        guard case Error.timeout = event else {
            return .pending
        }
        
        context.logger.notice("Did not receive 'Subscription Acknowledgement' in time")
        return .failure(MQTTConnectionError.timeoutWaitingForAcknowledgement)
    }
}
