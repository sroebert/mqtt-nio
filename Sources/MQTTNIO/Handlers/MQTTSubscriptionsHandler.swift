import NIO
import NIOConcurrencyHelpers
import Logging

protocol MQTTSubscriptionsHandlerDelegate: class {
    func mqttSubscriptionsHandler(_ handler: MQTTSubscriptionsHandler, didReceiveMessage message: MQTTMessage)
}

final class MQTTSubscriptionsHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let logger: Logger
    private(set) var inflightMessages: [UInt16: MQTTMessage]
    
    weak var delegate: MQTTSubscriptionsHandlerDelegate?
    
    // MARK: - Init
    
    init(logger: Logger, inflightMessages: [UInt16: MQTTMessage] = [:]) {
        self.logger = logger
        self.inflightMessages = inflightMessages
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
        logger.debug("Emitting message to listeners", metadata: [
            "topic": .string(message.topic),
            "payload": .string(message.stringValue ?? message.payload.map { "\($0.readableBytes) bytes" } ?? "empty"),
            "qos": .stringConvertible(message.qos.rawValue),
            "retain": .stringConvertible(message.retain)
        ])
        
        delegate?.mqttSubscriptionsHandler(self, didReceiveMessage: message)
    }
    
    private func handlePublish(_ publish: MQTTPacket.Publish, context: ChannelHandlerContext) {
        logger.debug("Received: Publish", metadata: [
            "packetId": .string(publish.packetId.map { $0.description } ?? "none"),
            "topic": .string(publish.message.topic),
            "payload": .string(publish.message.stringValue ?? publish.message.payload.map { "\($0.readableBytes) bytes" } ?? "empty"),
            "qos": .stringConvertible(publish.message.qos.rawValue),
            "retain": .stringConvertible(publish.message.retain)
        ])
        
        switch publish.message.qos {
        case .atMostOnce:
            emit(publish.message)
            
        case .atLeastOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                return
            }
            
            logger.debug("Sending: Publish Acknowledgement", metadata: [
                "packetId": .stringConvertible(packetId),
            ])
            
            let packet = MQTTPacket.Acknowledgement(kind: .pubAck, packetId: packetId)
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            emit(publish.message)
            
        case .exactlyOnce:
            guard let packetId = publish.packetId else {
                // Should never happen, as this case is already handled
                return
            }
            
            logger.debug("Sending: Publish Received", metadata: [
                "packetId": .stringConvertible(packetId),
            ])
            
            let packet = MQTTPacket.Acknowledgement(kind: .pubRec, packetId: packetId)
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
            
            if inflightMessages[packetId] == nil {
                inflightMessages[packetId] = publish.message
            }
        }
    }
    
    private func handleAcknowledgement(packetId: UInt16, context: ChannelHandlerContext) {
        logger.debug("Received: Publish Release", metadata: [
            "packetId": .stringConvertible(packetId),
        ])
        
        logger.debug("Sending: Publish Complete", metadata: [
            "packetId": .stringConvertible(packetId),
        ])
        
        let packet = MQTTPacket.Acknowledgement(kind: .pubComp, packetId: packetId)
        context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
        
        guard let message = inflightMessages[packetId] else {
            logger.debug("Received 'Publish Release' for unknown packet identifier", metadata: [
                "packetId": .stringConvertible(packetId),
            ])
            return
        }
                
        inflightMessages.removeValue(forKey: packetId)
        emit(message)
    }
}
