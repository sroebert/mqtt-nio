extension String {
    
    /// Indicates whether the string is a valid MQTT topic to which can be published.
    public var isValidMqttTopic: Bool {
        guard isValidMqttTopicFilter else {
            return false
        }
        
        return !contains { $0 == "#" || $0 == "+" }
    }
    
    /// Indicates whether the string is a valid MQTT topic filter to which can be subscribed.
    public var isValidMqttTopicFilter: Bool {
        guard !isEmpty && utf8.count <= 65535 && !utf8.contains(0) else {
            return false
        }
        
        var parts = split(separator: "/", omittingEmptySubsequences: false)
        if parts.last == "#" {
            parts.removeLast()
        }
        
        return !parts.contains { part in
            part != "+" && part.contains { $0 == "#" || $0 == "+" }
        }
    }
    
    /// Indicates whether this string matches a given topic filter.
    ///
    /// This function takes into account wildcards (+ and #) in the topic filter when determining if the string matches.
    /// - Parameter topicFilter: The topic filter to match this string with.
    /// - Returns: `true` if the string matches the topic filter, `false` otherwise.
    public func matchesMqttTopicFilter(_ topicFilter: String) -> Bool {
        if starts(with: "$") && (topicFilter.starts(with: "#") || topicFilter.starts(with: "+")) {
            return false
        }
        
        var filterParts = topicFilter.split(separator: "/", omittingEmptySubsequences: false)
        var topicParts = split(separator: "/", omittingEmptySubsequences: false)
        
        while !filterParts.isEmpty && !topicParts.isEmpty {
            guard filterParts[0] == topicParts[0] || filterParts[0] == "+" else {
                return filterParts.count == 1 && filterParts[0] == "#"
            }
            
            filterParts.removeFirst()
            topicParts.removeFirst()
        }
        
        return (filterParts.isEmpty || (filterParts.count == 1 && filterParts[0] == "#")) && topicParts.isEmpty
    }
}
