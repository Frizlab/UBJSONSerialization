import XCTest

@testable import UBJSONSerializationTests

var tests: [XCTestCaseEntry] = [
	testCase([
	]),
	testCase([
		("testExample", UBJSONSerializationTests.testExample),
	]),
]
XCTMain(tests)
