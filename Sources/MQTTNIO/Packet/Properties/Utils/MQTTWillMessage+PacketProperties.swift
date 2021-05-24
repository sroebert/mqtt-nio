extension MQTTWillMessage {
    @ArrayBuilder<MQTTProperty>
    var packetProperties: [MQTTProperty] {
        if let interval = properties.delayInterval {
            .willDelayInterval(UInt32(interval.seconds))
        }
        
        switch payload {
        case .empty, .bytes:
            .payloadFormatIndicator(0)
            
        case .string:
            .payloadFormatIndicator(1)
        }
        
        if let interval = properties.expiryInterval {
            .messageExpiryInterval(UInt32(interval.seconds))
        }
        
        if case .string(_, let contentType?) = payload {
            .contentType(contentType)
        }
        
        if let configuration = properties.requestConfiguration {
            .responseTopic(configuration.responseTopic)
            
            if let data = configuration.correlationData {
                .correlationData(data.byteBuffer)
            }
        }
        
        for userProperty in properties.userProperties {
            .userProperty(.init(
                key: userProperty.name,
                value: userProperty.value
            ))
        }
    }
}
