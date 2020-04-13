@testable import MQTTNIO
import XCTest

class SizeTests: XCTestCase {
    
    // MARK: - Utils
    
    let existentialContainerBufferSize = 24

    private func checkSize<T>(of: T.Type, file: StaticString = #file, line: UInt = #line) {
        XCTAssertLessThanOrEqual(MemoryLayout<T>.size, existentialContainerBufferSize, file: file, line: line)
    }
    
    // MARK: - Tests
    
    func testPacketSize() {
        checkSize(of: MQTTPacket.self)
    }
    
    func testAcknowledgementSize() {
        checkSize(of: MQTTPacket.Acknowledgement.self)
    }
    
    func testConnectionAcknowledgementSize() {
        checkSize(of: MQTTPacket.ConnAck.self)
    }
    
    func testConnectSize() {
        checkSize(of: MQTTPacket.Connect.self)
    }
    
    func testDisconnect() {
        checkSize(of: MQTTPacket.Disconnect.self)
    }
    
    func testPingRequestSize() {
        checkSize(of: MQTTPacket.PingReq.self)
    }
    
    func testPingReponseSize() {
        checkSize(of: MQTTPacket.PingResp.self)
    }
    
    func testPublishSize() {
        checkSize(of: MQTTPacket.Publish.self)
    }
    
    func testSubscribeAcknowledgementSize() {
        checkSize(of: MQTTPacket.SubAck.self)
    }
    
    func testSubscribeSize() {
        checkSize(of: MQTTPacket.Subscribe.self)
    }
    
    func testUnsubscribeAcknowledgementSize() {
        checkSize(of: MQTTPacket.UnsubAck.self)
    }
    
    func testUnsubscribeSize() {
        checkSize(of: MQTTPacket.Unsubscribe.self)
    }
    
    func testInboundSize() {
        checkSize(of: MQTTPacket.Inbound.self)
    }
}
