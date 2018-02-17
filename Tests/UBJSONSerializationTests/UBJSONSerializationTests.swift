import XCTest
@testable import UBJSONSerialization



class UBJSONSerializationTests: XCTestCase {
	
	func testDecodeNil() {
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("Z".utf8)))
	}
	
	func testDecodeNop() {
		XCTAssertTrue(try UBJSONSerialization.ubjsonObject(with: Data("N".utf8), options: .returnNop).flatMap{ $0 is Nop } ?? false)
	}
	
}
