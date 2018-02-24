import XCTest
@testable import UBJSONSerialization



class UBJSONSerializationTests: XCTestCase {
	
	func testGarbageAtEndError() {
		XCTAssertThrowsError(try UBJSONSerialization.ubjsonObject(with: Data("ZZ".utf8), options: []))
	}
	
	func testDecodeNil() {
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("Z".utf8)))
	}
	
	func testDecodeNop() {
		XCTAssertTrue(try UBJSONSerialization.ubjsonObject(with: Data("N".utf8), options: .returnNopElements).flatMap{ $0 is Nop } ?? false)
	}
	
	func testNopSkipping() {
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("NZ".utf8), options: []))
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("NNZ".utf8), options: []))
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("NZN".utf8), options: []))
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("ZNN".utf8), options: []))
	}
	
}
