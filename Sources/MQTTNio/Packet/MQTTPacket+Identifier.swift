import NIO

extension MQTTPacket {
    struct Identifier: ExpressibleByIntegerLiteral, Equatable, CustomStringConvertible {
        
        static let connect: Identifier       = 0x10
        static let connAck: Identifier       = 0x20
        
        static let publish: Identifier       = 0x30
        static let pubAck: Identifier        = 0x40
        static let pubRec: Identifier        = 0x50
        static let pubRel: Identifier        = 0x60
        static let pubComp: Identifier       = 0x70
        
        static let subscribe: Identifier     = 0x80
        static let subAck: Identifier        = 0x90
        static let unsubscribe: Identifier   = 0xA0
        static let unsubAck: Identifier      = 0xB0
        
        static let pingReq: Identifier       = 0xC0
        static let pingResp: Identifier      = 0xD0
        
        static let disconnect: Identifier    = 0xE0
        
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
                
            default:
                return String(value)
            }
        }
    }
    
//    public struct Flags: OptionSet {
//        public let rawValue: UInt8
//
//        public static let retain   = Flags(rawValue: 1 << 0)
//        public static let qos1     = Flags(rawValue: 1 << 1)
//        public static let qos2     = Flags(rawValue: 1 << 2)
//        public static let dup      = Flags(rawValue: 1 << 3)
//
//        public init(rawValue: UInt8) {
//            self.rawValue = rawValue
//        }
//
//        public var description: String {
//            return [
//                "retain": contains(.retain),
//                "qos1": contains(.qos1),
//                "qos2": contains(.qos2),
//                "dup": contains(.dup),
//            ].description
//        }
//    }
}
