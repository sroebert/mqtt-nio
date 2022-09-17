#if swift(>=5.5) && canImport(_Concurrency)
public typealias MQTTSendable = Sendable
#else
public typealias MQTTSendable = Any
#endif

#if swift(>=5.6)
@preconcurrency public protocol MQTTPreconcurrencySendable: Sendable {}
#else
public protocol MQTTPreconcurrencySendable {}
#endif
