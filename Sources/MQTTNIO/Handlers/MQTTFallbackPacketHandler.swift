import NIO
import NIOConcurrencyHelpers
import Logging

protocol MQTTFallbackPacketHandlerDelegate: AnyObject {
    func fallbackPacketHandler(_ handler: MQTTFallbackPacketHandler, didReceiveDisconnectWith reason: MQTTDisconnectReason.ServerReason?, channel: Channel)
}

final class MQTTFallbackPacketHandler: ChannelDuplexHandler {
    
    // MARK: - Types
    
    typealias InboundIn = MQTTPacket.Inbound
    typealias OutboundIn = Never
    typealias OutboundOut = MQTTPacket.Outbound
    
    // MARK: - Vars
    
    let version: MQTTProtocolVersion
    let logger: Logger
    
    weak var delegate: MQTTFallbackPacketHandlerDelegate?
    
    // MARK: - Init
    
    init(
        version: MQTTProtocolVersion,
        logger: Logger
    ) {
        self.version = version
        self.logger = logger
    }
    
    // MARK: - ChannelDuplexHandler
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let packet = unwrapInboundIn(data)
        
        guard version >= .version5 else {
            // Versions lower than 5 do not support reasons
            logUnprocessedPacket(packet)
            return
        }
        
        switch packet {
        case .acknowledgement(let acknowledgement):
            handle(acknowledgement, context: context)
            
        case .disconnect(let disconnect):
            handle(disconnect, context: context)
            
        default:
            logUnprocessedPacket(packet)
        }
    }
    
    // MARK: - Log
    
    private func logUnprocessedPacket(_ packet: MQTTPacket.Inbound) {
        logger.debug("Received unprocessed packet", metadata: [
            "kind": "\(packet)"
        ])
    }
    
    // MARK: - Handle
    
    private func handle(_ acknowledgement: MQTTPacket.Acknowledgement, context: ChannelHandlerContext) {
        switch acknowledgement.kind {
        case .pubAck, .pubComp:
            // It can happen that we receive more than one .pubAck or .pubComp, simply ignore
            break
            
        case .pubRec, .pubRel:
            // If we receive an unhandled pubRel or pubRec, let the broker know it is unknown.
            logger.debug("Received invalid acknowledgement for packet identifier", metadata: [
                "packetId": .stringConvertible(acknowledgement.packetId),
            ])
            
            let packet: MQTTPacket.Acknowledgement
            if acknowledgement.kind == .pubRec {
                packet = .pubRel(
                    packetId: acknowledgement.packetId,
                    notFound: true
                )
            } else {
                packet = .pubComp(
                    packetId: acknowledgement.packetId,
                    notFound: true
                )
            }
            context.writeAndFlush(wrapOutboundOut(packet), promise: nil)
        }
    }
    
    private func handle(_ disconnect: MQTTPacket.Disconnect, context: ChannelHandlerContext) {
        let reason: MQTTDisconnectReason.ServerReason?
        if let code = disconnect.reasonCode.disconnectReasonCode(with: disconnect.properties) {
            reason = MQTTDisconnectReason.ServerReason(
                code: code,
                message: disconnect.properties.reasonString
            )
        } else {
            reason = nil
        }
        
        delegate?.fallbackPacketHandler(self, didReceiveDisconnectWith: reason, channel: context.channel)
    }
}

extension MQTTPacket.Disconnect.ReasonCode {
    fileprivate func disconnectReasonCode(
        with properties: MQTTProperties
    ) -> MQTTDisconnectReason.ServerReason.Code? {
        switch self {
        case .normalDisconnection: return nil
        case .disconnectWithWillMessage: return nil
        case .unspecifiedError: return .unspecifiedError
        case .malformedPacket: return .malformedPacket
        case .protocolError: return .protocolError
        case .implementationSpecificError: return .implementationSpecificError
        case .notAuthorized: return .notAuthorized
        case .serverBusy: return .serverBusy
        case .serverShuttingDown: return .serverShuttingDown
        case .keepAliveTimeout: return .keepAliveTimeout
        case .sessionTakenOver: return .sessionTakenOver
        case .topicFilterInvalid: return .topicFilterInvalid
        case .topicNameInvalid: return .topicNameInvalid
        case .receiveMaximumExceeded: return .receiveMaximumExceeded
        case .topicAliasInvalid: return .topicAliasInvalid
        case .packetTooLarge: return .packetTooLarge
        case .messageRateTooHigh: return .messageRateTooHigh
        case .quotaExceeded: return .quotaExceeded
        case .administrativeAction: return .administrativeAction
        case .payloadFormatInvalid: return .payloadFormatInvalid
        case .retainNotSupported: return .retainNotSupported
        case .qosNotSupported: return .qosNotSupported
        case .useAnotherServer: return .useAnotherServer(properties.serverReference)
        case .serverMoved: return .serverMoved(properties.serverReference)
        case .sharedSubscriptionsNotSupported: return .sharedSubscriptionsNotSupported
        case .connectionRateExceeded: return .connectionRateExceeded
        case .maximumConnectTime: return .maximumConnectTime
        case .subscriptionIdentifiersNotSupported: return .subscriptionIdentifiersNotSupported
        case .wildcardSubscriptionsNotSupported: return .wildcardSubscriptionsNotSupported
        }
    }
}
