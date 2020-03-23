import XCTest

import mqtt_nioTests

var tests = [XCTestCaseEntry]()
tests += mqtt_nioTests.allTests()
XCTMain(tests)
