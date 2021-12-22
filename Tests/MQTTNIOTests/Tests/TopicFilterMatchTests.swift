@testable import MQTTNIO
import XCTest

final class TopicFilterMatchTests: XCTestCase {
    func testTopicFilterMatches() {
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/two/three"))
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/+/three"))
        XCTAssertTrue("one/two/three".matchesMqttTopicFilter("one/#"))
        
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
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/two/three/#"))
        XCTAssertFalse("one/two/three".matchesMqttTopicFilter("one/two/three/+"))
    }
}
