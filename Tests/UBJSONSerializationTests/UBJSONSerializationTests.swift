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
	
	func testEncodeNil() {
		XCTAssertEqual(try UBJSONSerialization.data(withUBJSONObject: nil), Data("Z".utf8))
	}
	
	func testEncodeNop() {
		XCTAssertEqual(try UBJSONSerialization.data(withUBJSONObject: Nop()), Data("N".utf8))
	}
	
	func testEncodeInt8() {
		XCTAssertEqual(try UBJSONSerialization.data(withUBJSONObject: 42), Data(hexEncoded: "69 2A"))
	}
	
	func testEncodeOptimizedArrayOfInts() {
		XCTAssertEqual(try UBJSONSerialization.data(withUBJSONObject: [Int8(42), Int64(21), 12, 9, 3], options: [.optimizeIntsForSize, .enableContainerOptimization]), Data(hexEncoded: "5B 24 69 23 69 05 2A 15 0C 09 03"))
	}
	
}
