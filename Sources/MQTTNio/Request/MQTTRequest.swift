import Logging

protocol MQTTRequest {
    func start() throws -> MQTTPacket
    
    func shouldProcess(_ packet: MQTTPacket) throws -> Bool
    func process(_ packet: MQTTPacket, appendResponse: (MQTTPacket) -> Void) throws -> MQTTRequestProcessResult
    
    func log(to logger: Logger)
}

enum MQTTRequestProcessResult {
    case pending
    case success
    case failure(Error)
}
