import NIO
import NIOConcurrencyHelpers
import Logging

final class MQTTSubscriptionsHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = MQTTPacket.Outbound
    typealias OutboundOut = MQTTPacket.Outbound
    
    class ListenerEntry {
        let context: MQTTMessageListenContext
        let listener: MQTTMessageListener
        
        init(context: MQTTMessageListenContext, listener: @escaping MQTTMessageListener) {
            self.context = context
            self.listener = listener
        }
    }
    
    // MARK: - Vars
    
    let logger: Logger
    
    private let lock = Lock()
    
    private var listeners: [ListenerEntry] = []
    private var inflightMessages: [UInt16: MQTTMessage] = [:]
    
    // MARK: - Init
    
    init(logger: Logger) {
        self.logger = logger
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
    
    func addListener(_ entry: ListenerEntry) {
        lock.withLockVoid {
            listeners.append(entry)
        }
    }
    
    func removeListener(_ entry: ListenerEntry) {
        lock.withLockVoid {
            if let index = listeners.firstIndex(where: { $0 === entry }) {
                listeners.remove(at: index)
            }
        }
    }
    
    private func emit(_ message: MQTTMessage) {
        let currentListeners = lock.withLock { listeners }
        
        currentListeners.forEach { $0.listener($0.context, message) }
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
            
            lock.withLockVoid {
                if inflightMessages[packetId] == nil {
                    inflightMessages[packetId] = publish.message
                }
            }
        }
    }
    
    private func handleAcknowledgement(packetId: UInt16, context: ChannelHandlerContext) {
        let optionalMessage = lock.withLock { () -> MQTTMessage? in
            guard let message = inflightMessages[packetId] else {
                return nil
            }
                    
            inflightMessages.removeValue(forKey: packetId)
            return message
        }
        
        guard let message = optionalMessage else {
            return
        }
        
        let packet = MQTTPacket.Acknowledgement(kind: .pubComp, packetId: packetId)
        context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
        
        emit(message)
    }
}
