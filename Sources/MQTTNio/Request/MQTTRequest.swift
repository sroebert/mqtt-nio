import Logging

protocol MQTTRequest {
    func start() throws -> MQTTRequestAction
    
    func shouldProcess(_ packet: MQTTPacket.Inbound) -> Bool
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction
    
    func log(to logger: Logger)
}

struct MQTTRequestAction {
    enum Status {
        case pending
        case success
        case failure(Error)
    }
    
    static let pending = MQTTRequestAction(nextStatus: .pending)
    static let success = MQTTRequestAction(nextStatus: .success)
    static func failure(_ error: Error) -> MQTTRequestAction {
        return .init(nextStatus: .failure(error))
    }
    
    var nextStatus: Status
    var response: MQTTPacket.Outbound?
    
    init(nextStatus: Status = .pending, response: MQTTPacket.Outbound? = nil) {
        self.nextStatus = nextStatus
        self.response = response
    }
}
