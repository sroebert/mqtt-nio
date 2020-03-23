import NIO

protocol MQTTPacketType {
    static var identifier: MQTTPacket.Identifier { get }
    
    static func parse(fixedHeaderData: UInt8, buffer: inout ByteBuffer) throws -> Self
    func serialize(fixedHeaderData: inout UInt8, buffer: inout ByteBuffer) throws
}

extension MQTTPacketType {
    func message() throws -> MQTTPacket {
        var fixedHeaderData: UInt8 = 0
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try self.serialize(fixedHeaderData: &fixedHeaderData, buffer: &buffer)
        
        return  MQTTPacket(
            identifier: Self.identifier,
            fixedHeaderData: fixedHeaderData,
            data: buffer
        )
    }
    
    init(_ packet: MQTTPacket) throws {
        var packet = packet
        self = try Self.parse(fixedHeaderData: packet.fixedHeaderData, buffer: &packet.data)
    }
    
    static func parse(fixedHeaderData: UInt8, buffer: inout ByteBuffer) throws -> Self {
        fatalError("\(Self.self) does not support parsing.")
    }
    
    func serialize(fixedHeaderData: inout UInt8, buffer: inout ByteBuffer) throws {
        fatalError("\(Self.self) does not support serializing.")
    }
}
