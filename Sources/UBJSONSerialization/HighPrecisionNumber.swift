/*
 * HighPrecisionNumber.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 8/22/17.
 */

import Foundation



/**
To represent a high precision number. The wrapped value is guaranteed to be a
valid number (in terms of the [JSON number spec](http://json.org)).

- Note: The fact that `decimalPart` is non-nil does not necessarily mean the
number is not an int, and vice-versa. Indeed the decimal part can be equal to 0,
or the exponent can make the number int or decimal. However a nil decimal part
**and** a nil or non-negative exponent part guarantees the number is an int.

- Note: According to the specs, `".42"` is not a valid number. Nor is `"01"` or
`"+1"`. But `"1e01"` or `"1e+1"` are.

- Note: Two high-precision numbers are considered equal if their “normalized
string value” are equal. The normalized string value should always represent the
same high-precision number as the wrapped stringValue, even though both strings
might not always be the same. The normalized string value will simply remove any
leading zeros and the plus sign in the exponent, if any, and lowercase the “e“
if the number contains an exponent. It will keep trailing zeros on the decimal
part of the number though (in science, `1.10e10 != 1.1e10`). There can't be any
leading 0 or plus sign on the integer part of a valid high precision number
(JSON specs). */
public struct HighPrecisionNumber : Equatable, Hashable {
	
	public enum Digit : String {
		case d0 = "0"
		case d1 = "1"
		case d2 = "2"
		case d3 = "3"
		case d4 = "4"
		case d5 = "5"
		case d6 = "6"
		case d7 = "7"
		case d8 = "8"
		case d9 = "9"
	}
	
	public struct NoExponentHighPrecisionInt {
		
		public let hasNegativeSign: Bool
		public let unsignedIntPart: [Digit]
		
		public let normalizedStringValue: String
		
		private struct Parser {
			
			/** Waits for a "-", or a digit. */
			private static func waitStart(_ char: Character, _ parser: inout Parser) -> Bool {
				if let d = Digit(rawValue: String(char)) {
					parser.unsignedIntPart.append(d)
					parser.engine = waitDigitEnd
					return true
				}
				
				switch char {
				case "-": parser.hasNegativeSign = true;                           parser.engine = waitDigitEnd; return true
				case "+": guard parser.allowLeadingZeroOrPlus else {return false}; parser.engine = waitDigitEnd; return true
				default: return false
				}
			}
			
			private static func waitDigitEnd(_ char: Character, _ parser: inout Parser) -> Bool {
				guard parser.unsignedIntPart != [.d0] || parser.allowLeadingZeroOrPlus else {return false}
				guard let d = Digit(rawValue: String(char)) else {return false}
				parser.unsignedIntPart.append(d)
				return true
			}
			
			/** - Returns: `true` if character is valid and parsing can continue. */
			private typealias Engine = (_ char: Character, _ parser: inout Parser) -> Bool
			private var engine: Engine = Parser.waitStart
			private var unsignedIntPart = [Digit]()
			private var hasNegativeSign = false
			
			let inputString: String
			let allowLeadingZeroOrPlus: Bool
			
			init(parsedString: String, allowLeadingZeroOrPlus z: Bool) {
				allowLeadingZeroOrPlus = z
				inputString = parsedString
			}
			
			mutating func parse() -> (hasNegativeSign: Bool, unsignedIntPart: [Digit], parsedLength: String.IndexDistance) {
				engine = Parser.waitStart
				
				var readCount = 0
				for c in inputString {
					guard engine(c, &self) else {return (hasNegativeSign, unsignedIntPart, readCount)}
					readCount += 1
				}
				
				return (hasNegativeSign, unsignedIntPart, readCount)
			}
			
		}
		
		init?(stringValue: String, startIndex: inout String.Index, allowLeadingZeroOrPlus: Bool) {
			guard startIndex < stringValue.endIndex else {return nil} /* Let's make sure we have at least one char to read */
			
			var parser = Parser(parsedString: String(stringValue[startIndex...]), allowLeadingZeroOrPlus: allowLeadingZeroOrPlus)
			let parseOffset: String.IndexDistance; (hasNegativeSign, unsignedIntPart, parseOffset) = parser.parse()
			startIndex = stringValue.index(startIndex, offsetBy: parseOffset)
			
			guard !unsignedIntPart.isEmpty else {return nil}
			
			/* Computing normalized string value */
			let normalizedUnsignedIntStringPart: String
			if unsignedIntPart.count == 1 {normalizedUnsignedIntStringPart = unsignedIntPart[0].rawValue}
			else {
				var hasSeenNonZero = false
				normalizedUnsignedIntStringPart = unsignedIntPart.compactMap{
					hasSeenNonZero = (hasSeenNonZero || $0 != .d0)
					return hasSeenNonZero ? $0.rawValue : nil
				}.joined()
			}
			normalizedStringValue = (hasNegativeSign ? "-" : "") + normalizedUnsignedIntStringPart
		}
		
	}
	
	public let stringValue: String
	
	public let intPart: NoExponentHighPrecisionInt
	public let decimalPart: [Digit]?
	public let exponentPart: NoExponentHighPrecisionInt?
	
	public let normalizedStringValue: String
	
	public init(unparsedValue: String) throws {
		stringValue = unparsedValue
		
		var normalizedStringValueBuilding = ""
		var currentIndex = unparsedValue.startIndex
		guard let i = NoExponentHighPrecisionInt(stringValue: unparsedValue, startIndex: &currentIndex, allowLeadingZeroOrPlus: false) else {
			throw UBJSONSerializationError.invalidHighPrecisionNumber(unparsedValue)
		}
		normalizedStringValueBuilding += i.normalizedStringValue
		intPart = i
		
		decimalPart = HighPrecisionNumber.parseDecimalPart(string: unparsedValue, startIndex: &currentIndex)
		if let d = decimalPart {normalizedStringValueBuilding += "." + d.map{ $0.rawValue }.joined()}
		if currentIndex < unparsedValue.endIndex {
			guard unparsedValue[currentIndex] == "e" || unparsedValue[currentIndex] == "E" else {
				throw UBJSONSerializationError.invalidHighPrecisionNumber(unparsedValue)
			}
			currentIndex = unparsedValue.index(after: currentIndex)
			guard let e = NoExponentHighPrecisionInt(stringValue: unparsedValue, startIndex: &currentIndex, allowLeadingZeroOrPlus: true) else {
				throw UBJSONSerializationError.invalidHighPrecisionNumber(unparsedValue)
			}
			normalizedStringValueBuilding += "e" + e.normalizedStringValue
			exponentPart = e
		} else {
			exponentPart = nil
		}
		
		guard currentIndex == unparsedValue.endIndex else {
			throw UBJSONSerializationError.invalidHighPrecisionNumber(unparsedValue)
		}
		
		normalizedStringValue = normalizedStringValueBuilding
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(normalizedStringValue)
	}
	
	public static func ==(lhs: HighPrecisionNumber, rhs: HighPrecisionNumber) -> Bool {
		return lhs.normalizedStringValue == rhs.normalizedStringValue
	}
	
	private static func parseDecimalPart(string: String, startIndex: inout String.Index) -> [Digit]? {
		guard startIndex < string.endIndex else {return nil}
		guard string[startIndex] == "." else {return nil}
		
		var decimalPart = [Digit]()
		var currentStartIndex = string.index(after: startIndex)
		
		for c in string[currentStartIndex...] {
			guard let d = Digit(rawValue: String(c)) else {break}
			currentStartIndex = string.index(after: currentStartIndex)
			decimalPart.append(d)
		}
		
		guard !decimalPart.isEmpty else {return nil}
		
		startIndex = currentStartIndex
		return decimalPart
	}
	
}
