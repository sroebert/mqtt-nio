import NIO

protocol MQTTPropertyType {
    var identifier: Int { get }
    
    var serializedLength: Int { get }
    func serialize(into data: inout ByteBuffer) throws
}

@propertyWrapper
struct MQTTProperty<Value: Equatable, Intermediate, PropertyValue: MQTTPropertyValue>: MQTTPropertyType {
    
    // MARK: - Vars
    
    let identifier: Int
    let isAllowedMultipleTimes: Bool
    
    private let encode: (Value) -> [PropertyValue]
    private let decode: (PropertyValue) -> Intermediate
    private let combine: ((Value, Intermediate) -> Value)
    
    // MARK: - Init
    
    init(
        wrappedValue: Value,
        _ identifier: Int,
        isAllowedMultipleTimes: Bool = false,
        encode: @escaping (Value) -> [PropertyValue],
        decode: @escaping (PropertyValue) -> Intermediate,
        combine: @escaping (Value, Intermediate) -> Value
    ) {
        self.wrappedValue = wrappedValue
        self.identifier = identifier
        self.isAllowedMultipleTimes = isAllowedMultipleTimes
        self.encode = encode
        self.decode = decode
        self.combine = combine
    }
    
    // MARK: - Utils
    
    mutating func parse(from data: inout ByteBuffer) throws {
        let propertyValue = try PropertyValue.parsePropertyValue(from: &data)
        let intermediate = decode(propertyValue)
        wrappedValue = combine(wrappedValue, intermediate)
    }
    
    var serializedLength: Int {
        let propertyValues = encode(wrappedValue)
        guard !propertyValues.isEmpty else {
            return 0
        }
        
        let identifierLength = MQTTVariableByteInteger.size(for: identifier)
        return propertyValues.reduce(0) {
            $0 + identifierLength + $1.propertyValueLength
        }
    }
    
    func serialize(into data: inout ByteBuffer) throws {
        let propertyValues = encode(wrappedValue)
        
        for propertyValue in propertyValues {
            try data.writeMQTTVariableByteInteger(identifier, "Property identifier")
            try propertyValue.serializePropertyValue(into: &data)
        }
    }
    
    // MARK: - Property Wrapper
    
    var wrappedValue: Value
    
    var projectedValue: Self {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
}

extension MQTTProperty where Value == Intermediate {
    init(
        wrappedValue: Value,
        _ identifier: Int,
        isAllowedMultipleTimes: Bool = false,
        encode: @escaping (Value) -> [PropertyValue],
        decode: @escaping (PropertyValue) -> Intermediate
    ) {
        self.init(
            wrappedValue: wrappedValue,
            identifier,
            isAllowedMultipleTimes: isAllowedMultipleTimes,
            encode: encode,
            decode: decode
        ) { _, newValue in
            return newValue
        }
    }
}

extension MQTTProperty where Value == [Intermediate] {
    init(
        wrappedValue: Value,
        _ identifier: Int,
        isAllowedMultipleTimes: Bool = false,
        encode: @escaping (Value) -> [PropertyValue],
        decode: @escaping (PropertyValue) -> Intermediate
    ) {
        self.init(
            wrappedValue: wrappedValue,
            identifier,
            isAllowedMultipleTimes: isAllowedMultipleTimes,
            encode: encode,
            decode: decode
        ) { array, newValue in
            var array = array
            array.append(newValue)
            return array
        }
    }
}

extension MQTTProperty where Value == Intermediate, Value == PropertyValue {
    init(wrappedValue: Value, _ identifier: Int) {
        self.init(wrappedValue: wrappedValue, identifier) {
            guard $0 != wrappedValue else {
                return []
            }
            return [$0]
        } decode: {
            $0
        }
    }
}

extension MQTTProperty where Value == Intermediate, Value == PropertyValue? {
    init(_ identifier: Int) {
        self.init(wrappedValue: nil, identifier) {
            guard let value = $0 else {
                return []
            }
            return [value]
        } decode: {
            $0
        }
    }
}

extension MQTTProperty where Value == Int, Value == Intermediate, PropertyValue: FixedWidthInteger {
    init(wrappedValue: PropertyValue, _ identifier: Int, format: PropertyValue.Type) {
        self.init(wrappedValue: Int(wrappedValue), identifier) {
            guard $0 != wrappedValue else {
                return []
            }
            return [format.init($0)]
        } decode: {
            Int($0)
        }
    }
}

extension MQTTProperty where Value == Int?, Value == Intermediate, PropertyValue: FixedWidthInteger {
    init(_ identifier: Int, format: PropertyValue.Type) {
        self.init(wrappedValue: nil, identifier) {
            guard let value = $0 else {
                return []
            }
            return [format.init(value)]
        } decode: {
            Int($0)
        }
    }
}

extension MQTTProperty where Value == Bool, Value == Intermediate, PropertyValue == UInt8 {
    init(wrappedValue: Bool, _ identifier: Int) {
        self.init(wrappedValue: wrappedValue, identifier) {
            guard $0 != wrappedValue else {
                return []
            }
            return $0 ? [1] : [0]
        } decode: {
            $0 == 1
        }
    }
}

extension MQTTProperty where Value == Int, Value == Intermediate, PropertyValue == MQTTVariableByteInteger {
    init(wrappedValue: Int, _ identifier: Int) {
        self.init(wrappedValue: wrappedValue, identifier) {
            guard $0 != wrappedValue else {
                return []
            }
            return [MQTTVariableByteInteger(value: $0)]
        } decode: {
            $0.value
        }
    }
}

extension MQTTProperty where Value == Int?, Value == Intermediate, PropertyValue == MQTTVariableByteInteger {
    init(_ identifier: Int) {
        self.init(wrappedValue: nil, identifier) {
            guard let value = $0 else {
                return []
            }
            return [MQTTVariableByteInteger(value: value)]
        } decode: {
            $0.value
        }
    }
}

extension MQTTProperty where Value == TimeAmount?, Value == Intermediate, PropertyValue: FixedWidthInteger {
    init(_ identifier: Int, format: PropertyValue.Type) {
        self.init(wrappedValue: nil, identifier) {
            guard let value = $0 else {
                return []
            }
            return [format.init(value.seconds)]
        } decode: {
            .seconds(Int64($0))
        }
    }
}

extension MQTTProperty where Value == [MQTTUserProperty], Intermediate == MQTTUserProperty, PropertyValue == MQTTStringPair {
    init(_ identifier: Int) {
        self.init(wrappedValue: [], identifier, isAllowedMultipleTimes: true) {
            $0.map { MQTTStringPair(key: $0.name, value: $0.value) }
        } decode: {
            MQTTUserProperty(name: $0.key, value: $0.value)
        }
    }
}

extension MQTTProperty where Value == [Int], Intermediate == Int, PropertyValue == MQTTVariableByteInteger {
    init(_ identifier: Int) {
        self.init(wrappedValue: [], identifier, isAllowedMultipleTimes: true) {
            $0.map { MQTTVariableByteInteger(value: $0) }
        } decode: {
            $0.value
        }
    }
}

extension MQTTProperty where Value == MQTTConfiguration.SessionExpiry, Value == Intermediate, PropertyValue == UInt32 {
    init(_ identifier: Int) {
        self.init(wrappedValue: .atClose, identifier) {
            switch $0 {
            case .atClose:
                return []
            case .afterInterval(let timeAmount):
                return [UInt32(timeAmount.seconds)]
            case .never:
                return [UInt32.max]
            }
        } decode: {
            switch $0 {
            case 0:
                return .atClose
            case UInt32.max:
                return .never
            default:
                return .afterInterval(.seconds(Int64($0)))
            }
        }
    }
}

extension MQTTProperty where Value == MQTTQoS, Value == Intermediate, PropertyValue == UInt8 {
    init(_ identifier: Int) {
        self.init(wrappedValue: .exactlyOnce, identifier) {
            guard $0 != .exactlyOnce else {
                return []
            }
            return [$0.rawValue]
        } decode: {
            guard let qos = MQTTQoS(rawValue: $0) else {
                return .exactlyOnce
            }
            return qos
        }
    }
}
