import XCTest
@testable import UBJSONSerialization



class UBJSONSerializationTests: XCTestCase {
	
	func testDecodeNil() {
		XCTAssertNil(try UBJSONSerialization.ubjsonObject(with: Data("Z".utf8)))
	}
	
	func testDecodeNop() {
		XCTAssertTrue(try UBJSONSerialization.ubjsonObject(with: Data("N".utf8)).flatMap{ $0 is Nop } ?? false)
	}
	
	func testHighPrecisionNumberParsingFails() {
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "01"))
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "+1e01"))
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "1e"))
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "+1"))
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "-011"))
		XCTAssertThrowsError(try HighPrecisionNumber(unparsedValue: "1."))
	}
	
	func testHighPrecisionNumberStandardParsing() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "10.00e+001")
			XCTAssertEqual(n.normalizedStringValue, "10.00e1")
			XCTAssertFalse(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertEqual(n.decimalPart ?? [], [.d0, .d0])
			XCTAssertFalse(n.exponentPart?.hasNegativeSign ?? true)
			XCTAssertEqual(n.exponentPart?.unsignedIntPart ?? [], [.d0, .d0, .d1])
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testHighPrecisionNumberStandardParsing2() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "-10.00e1")
			XCTAssertEqual(n.normalizedStringValue, "-10.00e1")
			XCTAssertTrue(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertEqual(n.decimalPart ?? [], [.d0, .d0])
			XCTAssertFalse(n.exponentPart?.hasNegativeSign ?? true)
			XCTAssertEqual(n.exponentPart?.unsignedIntPart ?? [], [.d1])
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testHighPrecisionNumberStandardParsing3() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "-10.00E-01")
			XCTAssertEqual(n.normalizedStringValue, "-10.00e-1")
			XCTAssertTrue(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertEqual(n.decimalPart ?? [], [.d0, .d0])
			XCTAssertTrue(n.exponentPart?.hasNegativeSign ?? false)
			XCTAssertEqual(n.exponentPart?.unsignedIntPart ?? [], [.d0, .d1])
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testHighPrecisionNumberStandardParsing4() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "-10.00")
			XCTAssertEqual(n.normalizedStringValue, "-10.00")
			XCTAssertTrue(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertEqual(n.decimalPart ?? [], [.d0, .d0])
			XCTAssertNil(n.exponentPart)
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testHighPrecisionNumberStandardParsing5() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "-10")
			XCTAssertEqual(n.normalizedStringValue, "-10")
			XCTAssertTrue(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertNil(n.decimalPart)
			XCTAssertNil(n.exponentPart)
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
	func testHighPrecisionNumberStandardParsing6() {
		do {
			let n = try HighPrecisionNumber(unparsedValue: "-10e1500")
			XCTAssertEqual(n.normalizedStringValue, "-10e1500")
			XCTAssertTrue(n.intPart.hasNegativeSign)
			XCTAssertEqual(n.intPart.unsignedIntPart, [.d1, .d0])
			XCTAssertNil(n.decimalPart)
			XCTAssertFalse(n.exponentPart?.hasNegativeSign ?? true)
			XCTAssertEqual(n.exponentPart?.unsignedIntPart ?? [], [.d1, .d5, .d0, .d0])
		} catch {
			XCTFail(error.localizedDescription)
		}
	}
	
}
