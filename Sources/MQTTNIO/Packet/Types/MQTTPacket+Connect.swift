import NIO
import Logging

extension MQTTPacket {
    struct Connect: MQTTPacketOutboundType {
        
        // MARK: - Vars
        
        private static let protocolName = "MQTT"
        
        private let data: Data
        
        // MARK: - Init
        
        init(
            configuration: MQTTConfiguration,
            authenticationMethod: String?,
            authenticationData: ByteBuffer?
        ) {
            data = Data(
                configuration: configuration,
                authenticationMethod: authenticationMethod,
                authenticationData: authenticationData
            )
        }
        
        // MARK: - Utils
        
        private var properties: MQTTProperties {
            var properties = MQTTProperties()
            
            if data.configuration.sessionExpiry != .atClose {
                properties.sessionExpiry = data.configuration.sessionExpiry
            }
            
            properties.receiveMaximum = data.configuration.receiveMaximum
            properties.maximumPacketSize = data.configuration.maximumPacketSize
            properties.requestResponseInformation = data.configuration.requestResponseInformation
            properties.requestProblemInformation = data.configuration.requestProblemInformation
            properties.userProperties = data.configuration.userProperties
            
            properties.authenticationMethod = data.authenticationMethod
            properties.authenticationData = data.authenticationData
            
            return properties
        }
        
        private func willProperties(for message: MQTTWillMessage) -> MQTTProperties {
            var properties = MQTTProperties()
            
            switch message.payload {
            case .empty, .bytes:
                properties.payloadFormatIsUTF8 = false
                
            case .string(_, let contentType):
                properties.payloadFormatIsUTF8 = true
                properties.contentType = contentType
            }
            
            properties.willDelayInterval = message.properties.delayInterval
            properties.messageExpiryInterval = message.properties.expiryInterval
            properties.userProperties = message.properties.userProperties
            
            properties.responseTopic = message.properties.responseTopic
            properties.correlationData = message.properties.correlationData?.byteBuffer
            
            return properties
        }
        
        // MARK: - MQTTPacketOutboundType
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            
            let flagsIndex = try serializeVariableHeader(into: &buffer, version: version)
            let flags = try serializePayload(into: &buffer, version: version)
            buffer.setInteger(flags.rawValue, at: flagsIndex)
            
            return MQTTPacket(kind: .connect, data: buffer)
        }
        
        // MARK: - Serialize Utils
        
        private func serializeVariableHeader(
            into buffer: inout ByteBuffer,
            version: MQTTProtocolVersion
        ) throws -> Int {
            // Protocol name
            try buffer.writeMQTTString(Self.protocolName, "Protocol name")
            
            // Protocol level
            buffer.writeInteger(version.rawValue)
            
            // Leave room for flags
            let flagsIndex = buffer.writerIndex
            buffer.writeInteger(Flags().rawValue)
            
            // Keep alive
            if data.configuration.keepAliveInterval <= .seconds(0) {
                buffer.writeInteger(UInt16(0))
            } else if data.configuration.keepAliveInterval >= .seconds(Int64(UInt16.max)) {
                buffer.writeInteger(UInt16.max)
            } else {
                buffer.writeInteger(UInt16(data.configuration.keepAliveInterval.seconds))
            }
            
            // Properties
            if version >= .version5 {
                try properties.serialize(to: &buffer)
            }
        
            return flagsIndex
        }
        
        private func serializePayload(
            into buffer: inout ByteBuffer,
            version: MQTTProtocolVersion
        ) throws -> Flags {
            var flags: Flags = []
            
            if data.configuration.clean {
                flags.insert(.clean)
            }
            
            try buffer.writeMQTTString(data.configuration.clientId, "Client Identifier")
            
            if let willMessage = data.configuration.willMessage {
                flags.insert(.containsWill)
                
                if version >= .version5 {
                    let properties = willProperties(for: willMessage)
                    try properties.serialize(to: &buffer)
                }
                
                try buffer.writeMQTTString(willMessage.topic, "Topic")
                
                switch willMessage.payload {
                case .empty:
                    var emptyData = ByteBuffer()
                    try buffer.writeMQTTDataWithLength(&emptyData, "Last Will Payload")
                    
                case .bytes(var bytes):
                    try buffer.writeMQTTDataWithLength(&bytes, "Last Will Payload")
                    
                case .string(let string, _):
                    try buffer.writeMQTTString(string, "Last Will Payload")
                }
                
                switch willMessage.qos {
                case .atMostOnce:
                    break
                case .atLeastOnce:
                    flags.insert(.willQoS1)
                case .exactlyOnce:
                    flags.insert(.willQoS2)
                }
                
                if willMessage.retain {
                    flags.insert(.willRetain)
                }
            }
            
            if let credentials = data.configuration.credentials {
                flags.insert(.containsUsername)
                try buffer.writeMQTTString(credentials.username, "Username")
                
                if var password = credentials.password {
                    flags.insert(.containsPassword)
                    try buffer.writeMQTTDataWithLength(&password, "Password")
                }
            }
            
            return flags
        }
    }
}

extension MQTTPacket.Connect {
    // Wrapper to avoid heap allocations when added to NIOAny
    private final class Data: MQTTSendable {
        let configuration: MQTTConfiguration
        let authenticationMethod: String?
        let authenticationData: ByteBuffer?
        
        init(
            configuration: MQTTConfiguration,
            authenticationMethod: String?,
            authenticationData: ByteBuffer?
        ) {
            self.configuration = configuration
            self.authenticationMethod = authenticationMethod
            self.authenticationData = authenticationData
        }
    }
    
    private struct Flags: OptionSet {
        let rawValue: UInt8
        
        static let clean = Flags(rawValue: 1 << 1)
        static let containsWill = Flags(rawValue: 1 << 2)
        static let willQoS1 = Flags(rawValue: 1 << 3)
        static let willQoS2 = Flags(rawValue: 1 << 4)
        static let willRetain = Flags(rawValue: 1 << 5)
        static let containsPassword = Flags(rawValue: 1 << 6)
        static let containsUsername = Flags(rawValue: 1 << 7)
        
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}
