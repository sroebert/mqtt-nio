import XCTest
import NIO

func assertSuccess<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) -> Value? {
    guard case .success(let value) = result else {
        XCTFail("Expected result to be successful", file: file, line: line)
        return nil
    }
    return value
}

func assertFailure<Value>(_ result: Result<Value, Error>, file: StaticString = #file, line: UInt = #line) -> Error? {
    guard case .failure(let error) = result else {
        XCTFail("Expected result to be a failure", file: file, line: line)
        return nil
    }
    return error
}

extension XCTestCase {
    @discardableResult
    func wait<T>(for future: EventLoopFuture<T>, timeout: TimeInterval = 2, file: StaticString = #file, line: UInt = #line) -> T? {
        var value: T?
        
        let expectation = XCTestExpectation(description: "Waiting for future completion")
        future.whenComplete { result in
            value = assertSuccess(result, file: file, line: line)
            expectation.fulfill()
        }
        
        let expectationResult = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(expectationResult, .completed, "Expected result to be successful", file: file, line: line)
        
        return value
    }
    
    @discardableResult
    func waitForFailure<T>(for future: EventLoopFuture<T>, timeout: TimeInterval = 2, file: StaticString = #file, line: UInt = #line) -> Error? {
        var error: Error?
        
        let expectation = XCTestExpectation(description: "Waiting for future completion")
        future.whenComplete { result in
            error = assertFailure(result, file: file, line: line)
            expectation.fulfill()
        }
        
        let expectationResult = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(expectationResult, .completed, "Expected result to be a failure", file: file, line: line)
        
        return error
    }
}
