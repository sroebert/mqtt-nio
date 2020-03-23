import NIO

extension MQTTPacket {
    struct Disconnect: MQTTPacketType {
        static var identifier: MQTTPacket.Identifier {
            return .disconnect
        }
        
        func serialize(fixedHeaderData: inout UInt8, buffer: inout ByteBuffer) throws {
            
        }
    }
}
