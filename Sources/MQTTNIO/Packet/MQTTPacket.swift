import NIO

struct MQTTPacket {
    var kind: Kind {
        get {
            return storage.kind
        }
        set {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy()
            }
            storage.kind = newValue
        }
    }
    
    var fixedHeaderData: UInt8 {
        get {
            return storage.fixedHeaderData
        }
        set {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy()
            }
            storage.fixedHeaderData = newValue
        }
    }
    
    var data: ByteBuffer {
        get {
            return storage.data
        }
        set {
            if !isKnownUniquelyReferenced(&storage) {
                storage = storage.copy()
            }
            storage.data = newValue
        }
    }
    
    private var storage: Storage

    init<Data>(kind: Kind, fixedHeaderData: UInt8 = 0, bytes: Data)
        where Data: Sequence, Data.Element == UInt8
    {
        self.init(
            kind: kind,
            fixedHeaderData: fixedHeaderData,
            data: bytes.byteBuffer
        )
    }
    
    init(headerByte: UInt8, data: ByteBuffer) {
        self.init(
            kind: .init(integerLiteral: headerByte),
            fixedHeaderData: headerByte & 0x0F,
            data: data
        )
    }

    init(
        kind: Kind,
        fixedHeaderData: UInt8 = 0,
        data: ByteBuffer = Allocator.shared.buffer(capacity: 0)
    ) {
        storage = Storage(kind: kind, fixedHeaderData: fixedHeaderData, data: data)
    }
    
    // Wrapper to avoid heap allocations when added to NIOAny
    fileprivate class Storage {
        var kind: Kind
        var fixedHeaderData: UInt8
        var data: ByteBuffer
        
        init(kind: Kind, fixedHeaderData: UInt8, data: ByteBuffer) {
            self.kind = kind
            self.fixedHeaderData = fixedHeaderData
            self.data = data
        }
        
        func copy() -> Storage {
            return .init(
                kind: kind,
                fixedHeaderData: fixedHeaderData,
                data: data
            )
        }
    }
}
