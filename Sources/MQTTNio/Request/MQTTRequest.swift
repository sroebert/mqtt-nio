import Logging

protocol MQTTRequest {
    func start(using idProvider: MQTTRequestIdProvider) throws -> MQTTRequestAction
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction
    
    func log(to logger: Logger)
}

extension MQTTRequest {
    func process(_ packet: MQTTPacket.Inbound) throws -> MQTTRequestAction {
        return .pending
    }
}

protocol MQTTRequestIdProvider {
    func getNextPacketId() -> UInt16
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
    
    static func respond(_ response: MQTTPacket.Outbound) -> MQTTRequestAction {
        return .init(response: response)
    }
    
    var nextStatus: Status
    var response: MQTTPacket.Outbound?
    
    init(nextStatus: Status = .pending, response: MQTTPacket.Outbound? = nil) {
        self.nextStatus = nextStatus
        self.response = response
    }
}
