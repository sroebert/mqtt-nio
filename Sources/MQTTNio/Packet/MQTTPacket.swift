import NIO

struct MQTTPacket: Equatable {
    var identifier: Identifier
    var fixedHeaderData: UInt8
    var data: ByteBuffer

    init<Data>(identifier: Identifier, fixedHeaderData: UInt8 = 0, bytes: Data)
        where Data: Sequence, Data.Element == UInt8
    {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeBytes(bytes)
        
        self.init(
            identifier: identifier,
            fixedHeaderData: fixedHeaderData,
            data: buffer
        )
    }
    
    init(headerByte: UInt8, data: ByteBuffer) {
        self.init(
            identifier: .init(integerLiteral: headerByte),
            fixedHeaderData: headerByte & 0x0F,
            data: data
        )
    }

    init(identifier: Identifier, fixedHeaderData: UInt8 = 0, data: ByteBuffer) {
        self.identifier = identifier
        self.fixedHeaderData = fixedHeaderData
        self.data = data
    }
}
