import XCTest
import NIO

func assertSuccess<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) {
    guard case .success = result else { return XCTFail("Expected result to be successful", file: file, line: line) }
}

func assertFailure<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) {
    guard case .failure = result else { return XCTFail("Expected result to be a failure", file: file, line: line) }
}

extension XCTestCase {
    func wait<T>(for future: EventLoopFuture<T>, timeout: TimeInterval = 2, file: StaticString = #file, line: UInt = #line) {
        let expectation = XCTestExpectation(description: "Waiting for future completion")
        future.whenComplete { result in
            assertSuccess(result, file: file, line: line)
            expectation.fulfill()
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected result to be successful", file: file, line: line)
    }
}
