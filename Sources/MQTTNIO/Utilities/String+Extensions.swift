extension String {
    
    /// Indicates whether this string matches a given topic filter.
    ///
    /// This function takes into account wildcards (+ and #) in the topic filter when determining if the string matches.
    /// - Parameter topicFilter: The topic filter to match this string with.
    /// - Returns: `true` if the string matches the topic filter, `false` otherwise.
    public func matchesMqttTopicFilter(_ topicFilter: String) -> Bool {
        var filterParts = topicFilter.split(separator: "/", omittingEmptySubsequences: false)
        var topicParts = split(separator: "/", omittingEmptySubsequences: false)
        
        while !filterParts.isEmpty && !topicParts.isEmpty {
            guard filterParts[0] == topicParts[0] || filterParts[0] == "+" else {
                return filterParts.count == 1 && filterParts[0] == "#"
            }
            
            filterParts.removeFirst()
            topicParts.removeFirst()
        }
        
        return filterParts.isEmpty && topicParts.isEmpty
    }
}
