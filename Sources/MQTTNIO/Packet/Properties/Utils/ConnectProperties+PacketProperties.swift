extension MQTTConfiguration.ConnectProperties {
    @ArrayBuilder<MQTTProperty>
    var packetProperties: [MQTTProperty] {
        switch sessionExpiry {
        case .atClose:
            .none
            
        case .afterInterval(let interval):
            .sessionExpiryInterval(UInt32(interval.seconds))
            
        case .never:
            .sessionExpiryInterval(UInt32.max)
        }
        
        if let value = receiveMaximum {
            .receiveMaximum(UInt16(value))
        }
        
        if let size = maximumPacketSize {
            .maximumPacketSize(UInt32(size))
        }
        
        if topicAliasMaximum > 0 {
            .topicAliasMaximum(UInt16(topicAliasMaximum))
        }
        
        if requestResponseInformation {
            .requestResponseInformation(1)
        }
        
        if !requestProblemInformation {
            .requestProblemInformation(0)
        }
        
        for userProperty in userProperties {
            .userProperty(.init(
                key: userProperty.name,
                value: userProperty.value
            ))
        }
        
        if let handler = authenticationHandler {
            .authenticationMethod(handler.method)
            
            if let data = handler.initialData {
                .authenticationData(data.byteBuffer)
            }
        }
    }
}
