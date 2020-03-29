import NIO
import Logging

extension MQTTConnection {
    func send(_ request: MQTTRequest, logger: Logger) -> EventLoopFuture<Void> {
        request.log(to: logger)
        
        let promise = channel.eventLoop.makePromise(of: Void.self)
        let request = MQTTRequestEntry(request: request, promise: promise)
        
        channel.write(request).cascadeFailure(to: promise)
        channel.flush()
        
        return promise.futureResult
    }
}
