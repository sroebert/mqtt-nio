import NIO
import Logging

final class MQTTSubscriptionsHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    class ListenerEntry {
        let context: MQTTClientMessageListenContext
        let listener: MQTTClientMessageListener
        
        init(context: MQTTClientMessageListenContext, listener: @escaping MQTTClientMessageListener) {
            self.context = context
            self.listener = listener
        }
    }
    
    // MARK: - Vars
    
    let logger: Logger
    let retryInterval: TimeAmount
    
    var listeners: [ListenerEntry] = []
    
    private var inflightMessages: [UInt16: MQTTMessage] = [:]
    
    // MARK: - Init
    
    init(logger: Logger, retryInterval: TimeAmount = .seconds(5)) {
        self.logger = logger
        self.retryInterval = retryInterval
    }
    
    // MARK: - ChannelDuplexHandler
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        switch packet {
        case .publish(let publish):
            handlePublish(publish, context: context)
            
        case .acknowledgement(let acknowledgement) where acknowledgement.kind == .pubRel:
            handleAcknowledgement(packetId: acknowledgement.packetId, context: context)
            
        default:
            context.fireChannelRead(data)
        }
    }
    
    // MARK: - Utils
    
    private func emit(_ message: MQTTMessage) {
        listeners.forEach { $0.listener($0.context, message) }
    }
    
    private func handlePublish(_ publish: MQTTPacket.Publish, context: ChannelHandlerContext) {
        switch publish.message.qos {
        case .atMostOnce:
            emit(publish.message)
            
        case .atLeastOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                return
            }
            
            let packet = MQTTPacket.Acknowledgement(kind: .pubAck, packetId: packetId)
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            emit(publish.message)
            
        case .exactlyOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                return
            }
            
            let packet = MQTTPacket.Acknowledgement(kind: .pubRec, packetId: packetId)
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            
            if inflightMessages[packetId] == nil {
                inflightMessages[packetId] = publish.message
            }
        }
    }
    
    private func handleAcknowledgement(packetId: UInt16, context: ChannelHandlerContext) {
        guard let message = inflightMessages[packetId] else {
            return
        }
        
        inflightMessages.removeValue(forKey: packetId)
        
        let packet = MQTTPacket.Acknowledgement(kind: .pubComp, packetId: packetId)
        context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
        
        emit(message)
    }
}
