import NIO

extension MQTTPacket {
    struct Kind: ExpressibleByIntegerLiteral, Equatable, CustomStringConvertible {
        
        static let connect: Kind       = 0x10
        static let connAck: Kind       = 0x20
        
        static let publish: Kind       = 0x30
        static let pubAck: Kind        = 0x40
        static let pubRec: Kind        = 0x50
        static let pubRel: Kind        = 0x60
        static let pubComp: Kind       = 0x70
        
        static let subscribe: Kind     = 0x80
        static let subAck: Kind        = 0x90
        static let unsubscribe: Kind   = 0xA0
        static let unsubAck: Kind      = 0xB0
        
        static let pingReq: Kind       = 0xC0
        static let pingResp: Kind      = 0xD0
        
        static let disconnect: Kind    = 0xE0
        
        static let auth: Kind          = 0xF0
        
        let value: UInt8
        
        init(integerLiteral value: UInt8) {
            self.value = value & 0xF0
        }
        
        var description: String {
            switch self {
            case .connect: return "CONNECT"
            case .connAck: return "CONNACK"
            
            case .publish: return "PUBLISH"
            case .pubAck: return "PUBACK"
            case .pubRec: return "PUBREC"
            case .pubRel: return "PUBREL"
            case .pubComp: return "PUBCOMP"
            
            case .subscribe: return "SUBSCRIBE"
            case .subAck: return "SUBACK"
            case .unsubscribe: return "UNSUBSCRIBE"
            case .unsubAck: return "UNSUBACK"
            
            case .pingReq: return "PINGREQ"
            case .pingResp: return "PINGRESP"
            
            case .disconnect: return "DISCONNECT"
                
            case .auth: return "AUTH"
                
            default:
                return String(value)
            }
        }
    }
}
