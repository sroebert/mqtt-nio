#if swift(>=5.7)
/// A custom handler for acknowledgements of QoS 1 or 2 messages received from a 5.0 MQTT broker.
///
/// This allows the user to send a custom failure reason to the broker, optionally with user properties.
///
/// - Parameters:
///   - message: The message for which to return an acknowledgement response.
/// - Returns: A `MQTTAcknowledgementResponse` to send to the broker as an acknowledgement for the message.
public typealias MQTTAcknowledgementHandler = @Sendable (_ message: MQTTMessage) -> MQTTAcknowledgementResponse
#else
/// A custom handler for acknowledgements of QoS 1 or 2 messages received from a 5.0 MQTT broker.
///
/// This allows the user to send a custom failure reason to the broker, optionally with user properties.
///
/// - Parameters:
///   - message: The message for which to return an acknowledgement response.
/// - Returns: A `MQTTAcknowledgementResponse` to send to the broker as an acknowledgement for the message.
public typealias MQTTAcknowledgementHandler = (_ message: MQTTMessage) -> MQTTAcknowledgementResponse
#endif

/// Response object returned from a `MQTTAcknowledgementHandler` indicating the response for the received message.
public struct MQTTAcknowledgementResponse: MQTTSendable {
    
    /// Creates a success `MQTTAcknowledgementResponse`.
    public static var success: Self {
        return self.init(
            userProperties: [],
            error: nil
        )
    }
    
    /// Creates a success `MQTTAcknowledgementResponse`.
    /// - Parameters:
    ///   - userProperties: User properties send with the message acknowledgement. The default value is an empty array.
    public static func success(
        userProperties: [MQTTUserProperty] = []
    ) -> Self {
        return self.init(
            userProperties: userProperties,
            error: nil
        )
    }
    
    /// Creates an error `MQTTAcknowledgementResponse`.
    /// - Parameters:
    ///   - code: The code indicating the reason for the error.
    ///   - message: An optional message giving more information regarding the reason for failure. The default value is `nil`.
    ///   - userProperties: User properties send with the message acknowledgement. The default value is an empty array.
    public static func error(
        _ code: Error.Code,
        message: String? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> Self {
        return self.init(
            userProperties: userProperties,
            error: Error(code: code, message: message)
        )
    }
    
    /// User properties send with the message acknowledgement.
    public var userProperties: [MQTTUserProperty]
    
    /// An optional error indicating the message was not accepted.
    public var error: Error?
}

extension MQTTAcknowledgementResponse {
    /// An error which can be returned with an acknowledgement of a message to a 5.0 MQTT broker.
    public struct Error: MQTTSendable {
        
        public enum Code: MQTTSendable {
            /// The receiver does not accept the publish but either does not want to reveal the reason, or it does not match one of the other values.
            case unspecifiedError
            
            /// The publish is valid but the receiver is not willing to accept it.
            case implementationSpecificError
            
            /// The publish is not authorized.
            case notAuthorized
            
            /// The message topic is not accepted.
            case topicNameInvalid
            
            /// An implementation or administrative imposed limit has been exceeded.
            case quotaExceeded
        }
       
        /// The code indicating the reason for the error.
        public var code: Code
        
        /// An optional message giving more information regarding the reason for failure.
        public var message: String?
        
        /// Creates a `MQTTAcknowledgementResponse.Error`.
        /// - Parameters:
        ///   - code: The code indicating the reason for the error.
        ///   - message: An optional message giving more information regarding the reason for failure. The default value is `nil`.
        public init(
            code: Code,
            message: String? = nil
        ) {
            self.code = code
            self.message = message
        }
    }
}
