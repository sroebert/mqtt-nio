import NIO

struct MQTTPacket: Equatable {
    var kind: Kind
    var fixedHeaderData: UInt8
    var data: ByteBuffer

    init<Data>(kind: Kind, fixedHeaderData: UInt8 = 0, bytes: Data)
        where Data: Sequence, Data.Element == UInt8
    {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeBytes(bytes)
        
        self.init(
            kind: kind,
            fixedHeaderData: fixedHeaderData,
            data: buffer
        )
    }
    
    init(headerByte: UInt8, data: ByteBuffer) {
        self.init(
            kind: .init(integerLiteral: headerByte),
            fixedHeaderData: headerByte & 0x0F,
            data: data
        )
    }

    init(kind: Kind, fixedHeaderData: UInt8 = 0, data: ByteBuffer = ByteBufferAllocator().buffer(capacity: 0)) {
        self.kind = kind
        self.fixedHeaderData = fixedHeaderData
        self.data = data
    }
}
