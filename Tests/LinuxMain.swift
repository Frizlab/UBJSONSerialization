import XCTest

@testable import UBJSONSerializationTests

var tests: [XCTestCaseEntry] = [
	testCase([
	]),
	testCase([
		("testHighPrecisionNumberParsingFails", HighPrecisionNumberTests.testHighPrecisionNumberParsingFails),
		("testHighPrecisionNumberStandardParsing", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing),
		("testHighPrecisionNumberStandardParsing2", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing2),
		("testHighPrecisionNumberStandardParsing3", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing3),
		("testHighPrecisionNumberStandardParsing4", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing4),
		("testHighPrecisionNumberStandardParsing5", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing5),
		("testHighPrecisionNumberStandardParsing6", HighPrecisionNumberTests.testHighPrecisionNumberStandardParsing6),
	]),
	testCase([
	]),
	testCase([
		("testDecodeNil", UBJSONSerializationTests.testDecodeNil),
		("testDecodeNop", UBJSONSerializationTests.testDecodeNop),
	]),
]
XCTMain(tests)
