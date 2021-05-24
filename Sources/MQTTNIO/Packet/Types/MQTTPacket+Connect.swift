import NIO
import Logging

extension MQTTPacket {
    struct Connect: MQTTPacketOutboundType {
        private static let protocolName = "MQTT"
        
        private let configurationWrapper: ConfigurationWrapper
        
        init(configuration: MQTTConfiguration) {
            configurationWrapper = ConfigurationWrapper(configuration: configuration)
        }
        
        var configuration: MQTTConfiguration {
            return configurationWrapper.configuration
        }
        
        func serialize(version: MQTTProtocolVersion) throws -> MQTTPacket {
            var buffer = Allocator.shared.buffer(capacity: 0)
            
            let flagsIndex = try serializeVariableHeader(into: &buffer, version: version)
            let flags = try serializePayload(into: &buffer, version: version)
            buffer.setInteger(flags.rawValue, at: flagsIndex)
            
            return MQTTPacket(kind: .connect, data: buffer)
        }
        
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
            buffer.moveWriterIndex(forwardBy: 1)
            
            // Keep alive
            if configuration.keepAliveInterval <= .seconds(0) {
                buffer.writeInteger(UInt16(0))
            } else if configuration.keepAliveInterval >= .seconds(Int64(UInt16.max)) {
                buffer.writeInteger(UInt16.max)
            } else {
                buffer.writeInteger(UInt16(configuration.keepAliveInterval.seconds))
            }
            
            // Properties
            if version >= .version5 {
                let properties = configuration.connectProperties.packetProperties
                try buffer.writeMQTTProperties(properties)
            }
        
            return flagsIndex
        }
        
        private func serializePayload(
            into buffer: inout ByteBuffer,
            version: MQTTProtocolVersion
        ) throws -> Flags {
            var flags: Flags = []
            
            if configuration.clean {
                flags.insert(.clean)
            }
            
            try buffer.writeMQTTString(configuration.clientId, "Client Identifier")
            
            if let willMessage = configuration.willMessage {
                flags.insert(.containsWill)
                
                if version >= .version5 {
                    let properties = willMessage.packetProperties
                    try buffer.writeMQTTProperties(properties)
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
            
            if let credentials = configuration.credentials {
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
    fileprivate class ConfigurationWrapper {
        let configuration: MQTTConfiguration
        
        init(configuration: MQTTConfiguration) {
            self.configuration = configuration
        }
    }
    
    fileprivate struct Flags: OptionSet {
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
