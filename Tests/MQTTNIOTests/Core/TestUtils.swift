import XCTest
import NIO

func assertSuccess<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) {
    guard case .success = result else { return XCTFail("Expected result to be successful", file: file, line: line) }
}

func assertFailure<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) {
    guard case .failure = result else { return XCTFail("Expected result to be a failure", file: file, line: line) }
}

extension XCTestCase {
    @discardableResult
    func wait<T>(for future: EventLoopFuture<T>, timeout: TimeInterval = 2, file: StaticString = #file, line: UInt = #line) -> T? {
        var value: T?
        
        let expectation = XCTestExpectation(description: "Waiting for future completion")
        future.whenComplete { result in
            assertSuccess(result, file: file, line: line)
            expectation.fulfill()
            
            value = try? result.get()
        }
        
        let expectationResult = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(expectationResult, .completed, "Expected result to be successful", file: file, line: line)
        
        return value
    }
}
