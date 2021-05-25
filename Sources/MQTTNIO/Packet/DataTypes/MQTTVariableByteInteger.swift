struct MQTTVariableByteInteger: Hashable {
    var value: Int
    
    static func size(for value: Int) -> Int {
        var value = value
        var length = 0
        
        repeat {
            value /= 128
            length += 1
        } while value > 0 && length <= 4
        
        return length
    }
}
