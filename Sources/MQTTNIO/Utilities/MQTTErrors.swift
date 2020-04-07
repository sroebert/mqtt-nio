import Foundation

public enum MQTTConnectionError: Error {
    case connectionClosed
    case timeoutWaitingForAcknowledgement
    case identifierRejected
    case serverUnavailable
    case badUsernameOrPassword
    case notAuthorized
}

public enum MQTTProtocolError: Error {
    case unacceptableVersion
    case parsingError(String)
}

public enum MQTTPublishError: Error {
    case sessionCleared
}

public enum MQTTValueError: Error {
    case valueTooLarge(String)
}
