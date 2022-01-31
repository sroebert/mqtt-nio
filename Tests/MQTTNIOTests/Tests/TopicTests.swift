@testable import MQTTNIO
import XCTest

final class TopicTests: XCTestCase {
    func testTopicValidation() {
        XCTAssertTrue("/".isValidMqttTopic)
        XCTAssertTrue("/test".isValidMqttTopic)
        XCTAssertTrue("one/two/three".isValidMqttTopic)
        XCTAssertTrue("one//three".isValidMqttTopic)
        XCTAssertTrue("$SYS".isValidMqttTopic)
        XCTAssertTrue("$SYS/test".isValidMqttTopic)
        
        XCTAssertFalse("one/+/three".isValidMqttTopic)
        XCTAssertFalse("one/two/#".isValidMqttTopic)
        XCTAssertFalse("/+".isValidMqttTopic)
        XCTAssertFalse("/#".isValidMqttTopic)
        XCTAssertFalse("test/+".isValidMqttTopic)
        XCTAssertFalse("test/#".isValidMqttTopic)
        XCTAssertFalse("+/".isValidMqttTopic)
        XCTAssertFalse("+/test".isValidMqttTopic)
        XCTAssertFalse("one/+/three".isValidMqttTopic)
        XCTAssertFalse("#".isValidMqttTopic)
        XCTAssertFalse("+".isValidMqttTopic)
        XCTAssertFalse("".isValidMqttTopic)
        XCTAssertFalse("\u{0000}".isValidMqttTopic)
        XCTAssertFalse("#/".isValidMqttTopic)
        XCTAssertFalse("#/test".isValidMqttTopic)
        XCTAssertFalse("one/#/three".isValidMqttTopic)
        XCTAssertFalse("one/two#".isValidMqttTopic)
        XCTAssertFalse("one/two+".isValidMqttTopic)
        XCTAssertFalse("one/+two/three".isValidMqttTopic)
        XCTAssertFalse("one/two+/three".isValidMqttTopic)
    }
    
    func testTopicFilterValidation() {
        XCTAssertTrue("one/two/three".isValidMqttTopicFilter)
        XCTAssertTrue("one//three".isValidMqttTopicFilter)
        XCTAssertTrue("$SYS".isValidMqttTopicFilter)
        XCTAssertTrue("$SYS/test".isValidMqttTopicFilter)
        XCTAssertTrue("/".isValidMqttTopicFilter)
        XCTAssertTrue("/test".isValidMqttTopicFilter)
        XCTAssertTrue("#".isValidMqttTopicFilter)
        XCTAssertTrue("+".isValidMqttTopicFilter)
        XCTAssertTrue("one/+/three".isValidMqttTopicFilter)
        XCTAssertTrue("one/two/#".isValidMqttTopicFilter)
        XCTAssertTrue("/+".isValidMqttTopicFilter)
        XCTAssertTrue("/#".isValidMqttTopicFilter)
        XCTAssertTrue("test/+".isValidMqttTopicFilter)
        XCTAssertTrue("test/#".isValidMqttTopicFilter)
        XCTAssertTrue("+/".isValidMqttTopicFilter)
        XCTAssertTrue("+/test".isValidMqttTopicFilter)
        XCTAssertTrue("one/+/three".isValidMqttTopicFilter)
        
        XCTAssertFalse("".isValidMqttTopicFilter)
        XCTAssertFalse("\u{0000}".isValidMqttTopicFilter)
        XCTAssertFalse("#/".isValidMqttTopicFilter)
        XCTAssertFalse("#/test".isValidMqttTopicFilter)
        XCTAssertFalse("one/#/three".isValidMqttTopicFilter)
        XCTAssertFalse("one/two#".isValidMqttTopicFilter)
        XCTAssertFalse("one/two+".isValidMqttTopicFilter)
        XCTAssertFalse("one/+two/three".isValidMqttTopicFilter)
        XCTAssertFalse("one/two+/three".isValidMqttTopicFilter)
    }
    
    func testTopicFilterMatches() {
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/two/three"))
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/+/three"))
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/#"))
        
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("One/Two/Three"))
        
        XCTAssertFalse("/one/two/three".matchesMqttTopicFilter("one/two/three"))
        XCTAssertTrue("/one/two/three".matchesMqttTopicFilter("/one/two/three"))
        
        XCTAssertTrue("one/two/three/four/five/six".matchesMqttTopicFilter("one/two/#"))
        XCTAssertTrue("one/two/three/four/five/six".matchesMqttTopicFilter("one/+/three/#"))
        
        XCTAssertTrue("one/two/three/four/five/six".matchesMqttTopicFilter("one/+/three/#"))
        XCTAssertTrue("one/two/three/four/five/six".matchesMqttTopicFilter("one/+/three/#"))
        XCTAssertTrue("one/two/three/four/five/six".matchesMqttTopicFilter("one/two/+/four/+/six"))
        
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/two"))
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/+"))
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/two/three/four"))
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/two/three/#"))
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/two/three/+"))
        
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("#"))
        XCTAssertTrue("one".matchesMqttTopicFilter("one/#"))
        XCTAssertFalse("one".matchesMqttTopicFilter("one/+"))
        
        XCTAssertTrue("one//three".matchesMqttTopicFilter("one//three"))
        XCTAssertTrue("one//three".matchesMqttTopicFilter("one/#"))
        XCTAssertTrue("one//three".matchesMqttTopicFilter("one//#"))
        
        XCTAssertFalse("$SYS/test".matchesMqttTopicFilter("#"))
        XCTAssertFalse("$SYS/test".matchesMqttTopicFilter("#/test"))
        XCTAssertFalse("$SYS/test".matchesMqttTopicFilter("+"))
        XCTAssertFalse("$SYS/test".matchesMqttTopicFilter("+/test"))
        XCTAssertTrue("$SYS/test".matchesMqttTopicFilter("$SYS/+"))
        XCTAssertTrue("$SYS/test".matchesMqttTopicFilter("$SYS/#"))
        XCTAssertTrue("$SYS/test".matchesMqttTopicFilter("$SYS/test"))
    }
}
