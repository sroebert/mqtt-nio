import NIO
import NIOConcurrencyHelpers
import Logging

protocol MQTTSubscriptionsHandlerDelegate: AnyObject {
    func mqttSubscriptionsHandler(_ handler: MQTTSubscriptionsHandler, didReceiveMessage message: MQTTMessage)
}

/// Handler for receiving publish messages from the broker.
final class MQTTSubscriptionsHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    var acknowledgementHandler: MQTTAcknowledgementHandler?
    let logger: Logger
    
    weak var delegate: MQTTSubscriptionsHandlerDelegate?
    
    private var inflightMessages: [UInt16: MQTTMessage] = [:]
    
    // MARK: - Init
    
    init(
        acknowledgementHandler: MQTTAcknowledgementHandler?,
        logger: Logger
    ) {
        self.acknowledgementHandler = acknowledgementHandler
        self.logger = logger
    }
    
    // MARK: - ChannelDuplexHandler
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        switch packet {
        case .publish(let publish):
            handlePublish(publish, context: context)
            
        case .acknowledgement(let acknowledgement) where acknowledgement.kind == .pubRel:
            guard let message = inflightMessages[acknowledgement.packetId] else {
                // No message found for the packet id, forward down the chain
                context.fireChannelRead(data)
                return
            }
            
            handleAcknowledgement(
                for: message,
                packetId: acknowledgement.packetId,
                context: context
            )
            
        default:
            context.fireChannelRead(data)
        }
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        
        switch event {
        case MQTTConnectionEvent.didConnect(let isSessionPresent) where !isSessionPresent:
            inflightMessages.removeAll()
            
        default:
            break
        }
        
        context.triggerUserOutboundEvent(event, promise: promise)
    }
    
    // MARK: - Utils
    
    private func emit(_ message: MQTTMessage) {
        logger.debug("Emitting message to callbacks", metadata: [
            "topic": .string(message.topic),
            "payload": .string(message.payload.debugDescription),
            "qos": .stringConvertible(message.qos.rawValue),
            "retain": .stringConvertible(message.retain)
        ])
        
        delegate?.mqttSubscriptionsHandler(self, didReceiveMessage: message)
    }
    
    private func handlePublish(_ publish: MQTTPacket.Publish, context: ChannelHandlerContext) {
        logger.debug("Received: Publish", metadata: [
            "packetId": .string(publish.packetId.map { $0.description } ?? "none"),
            "topic": .string(publish.message.topic),
            "payload": .string(publish.message.payload.debugDescription),
            "qos": .stringConvertible(publish.message.qos.rawValue),
            "retain": .stringConvertible(publish.message.retain)
        ])
        
        switch publish.message.qos {
        case .atMostOnce:
            emit(publish.message)
            
        case .atLeastOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                // in the parsing of `MQTTPacket.Publish`
                return
            }
            
            let response = acknowledgementHandler?(publish.message)
            let packet = MQTTPacket.Acknowledgement.pubAck(
                packetId: packetId,
                response: response
            )
            
            logger.debug("Sending: Publish Acknowledgement", metadata: [
                "packetId": .stringConvertible(packetId),
                "reasonCode": .string("\(packet.reasonCode)")
            ])
            
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            emit(publish.message)
            
        case .exactlyOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                // in the parsing of `MQTTPacket.Publish`
                return
            }
            
            let response = acknowledgementHandler?(publish.message)
            let packet = MQTTPacket.Acknowledgement.pubRec(
                packetId: packetId,
                response: response
            )
            
            logger.debug("Sending: Publish Received", metadata: [
                "packetId": .stringConvertible(packetId),
                "reasonCode": .string("\(packet.reasonCode)")
            ])
            
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            
            if inflightMessages[packetId] == nil {
                inflightMessages[packetId] = publish.message
            }
        }
    }
    
    private func handleAcknowledgement(
        for message: MQTTMessage,
        packetId: UInt16,
        context: ChannelHandlerContext
    ) {
        logger.debug("Received: Publish Release", metadata: [
            "packetId": .stringConvertible(packetId),
        ])
        
        logger.debug("Sending: Publish Complete", metadata: [
            "packetId": .stringConvertible(packetId),
        ])
        
        let packet = MQTTPacket.Acknowledgement.pubComp(packetId: packetId)
        context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
                
        inflightMessages.removeValue(forKey: packetId)
        emit(message)
    }
}
