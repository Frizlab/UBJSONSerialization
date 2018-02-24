/*
 * UBJSONSerialization.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import SimpleStream



/** To represent the `No-Op` element of UBJSON. */
public struct Nop : Equatable {
	public static let sharedNop = Nop()
	public static func ==(lhs: Nop, rhs: Nop) -> Bool {return true}
	public static func ==(lhs: Any?, rhs: Nop) -> Bool {return lhs is Nop}
}


final public class UBJSONSerialization {
	
	public struct ReadingOptions : OptionSet {
		
		public let rawValue: Int
		
		/**
		Allow high-precision numbers (numbers formatted as Strings). Will be
		returned as HighPrecisionNumber, which is basically a wrapper for the
		string-encoded value.
		
		The serialization will make sure the returned wrapped string is a valid
		high-precision number (follows the [JSON number spec](http://json.org)).
		
		You can use something like [BigInt](https://github.com/lorentey/BigInt) to
		handle big integers. Note high-precision numbers can also be decimals. */
		public static let allowHighPrecisionNumbers = ReadingOptions(rawValue: 1 << 0)
		
		/**
		Allows returning the `Nop` deserialized object. By default the `No-Op`
		element is skipped when deserializing UBJSON.
		
		Note this applies only to `No-Op` elements at the root of the UBJSON
		document being deserialized. For embedded `No-Op`s, see
		`.keepNopElementsInArrays`. */
		public static let returnNopElements = ReadingOptions(rawValue: 2 << 0)
		
		/**
		Return `Nop` objects when receiving the serialized `No-Op` element in an
		array. Specs says this element is a valueless value, so in array, it
		should simply be skipped: for this input, `["a", Nop, "b"]`, we should
		return `["a", "b"]`. This option allows you to keep the `Nop` in the
		deserialized array. */
		public static let keepNopElementsInArrays = ReadingOptions(rawValue: 3 << 0)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public struct WritingOptions : OptionSet {
		
		public let rawValue: Int
		/* Empty. We just create the enum in case we want to add something to it later. */
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public class func ubjsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any? {
		let simpleDataStream = SimpleDataStream(data: data)
		return try ubjsonObject(with: simpleDataStream, options: opt)
	}
	
	public class func ubjsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> Any? {
		let simpleInputStream = SimpleInputStream(stream: stream, bufferSize: 1024*1024, streamReadSizeLimit: nil)
		return try ubjsonObject(with: simpleInputStream, options: opt)
	}
	
	/* Note: We're using the SimpleStream method instead of InputStream for
	 *       conveninence, but using InputStream directly would probably be
	 *       faster. Also we don't need all of the “clever” bits of SimpleStream,
	 *       so one day we should migrate, or at least measure the performances
	 *       of both. */
	class func ubjsonObject(with simpleStream: SimpleStream, options opt: ReadingOptions = []) throws -> Any? {
		/* We assume Swift will continue to use the IEEE 754 spec for representing
		 * floats and doubles forever. Use of the spec validated in August 2017
		 * by @jckarter: https://twitter.com/jckarter/status/900073525905506304 */
		precondition(MemoryLayout<Float>.size == 4, "I currently need Float to be 32 bits")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		/* TODO: Handle endianness! UBSJON is big endian. */
		
		let elementType = try self.elementType(from: simpleStream, allowNop: opt.contains(.returnNopElements))
		return try element(from: simpleStream, type: elementType, options: opt)
	}
	
	public class func data(withUBJSONObject UBJSONObject: Any?, options opt: WritingOptions = []) throws -> Data {
		throw NSError(domain: "todo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"])
	}
	
	public class func writeUBJSONObject(_ UBJSONObject: Any?, to stream: OutputStream, options opt: WritingOptions = []) throws -> Int {
		throw NSError(domain: "todo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"])
	}
	
	public class func isValidUBJSONObject(_ obj: Any?) -> Bool {
		return false
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum InternalUBJSONElement : Equatable {
		
		case arrayEnd
		case objectEnd
		
		case containerType(UBJSONElementType)
		case containerCount(Int)
		
		static func ==(lhs: UBJSONSerialization.InternalUBJSONElement, rhs: UBJSONSerialization.InternalUBJSONElement) -> Bool {
			switch (lhs, rhs) {
			case (.arrayEnd, .arrayEnd):   return true
			case (.objectEnd, .objectEnd): return true
			case (.containerType(let lt), .containerType(let rt))   where lt == rt: return true
			case (.containerCount(let lc), .containerCount(let rc)) where lc == rc: return true
			default: return false
			}
		}
		
		static func ==(lhs: Any?, rhs: UBJSONSerialization.InternalUBJSONElement) -> Bool {
			guard let lhs = lhs as? InternalUBJSONElement else {return false}
			return lhs == rhs
		}
		
	}
	
	/** The recognized UBJSON element types. */
	private enum UBJSONElementType : UInt8 {
		
		/** A null element. No payload. */
		case null = 0x5a /* "Z" */
		
		/** This is the No-Op element. Converts to nothing. Might be used for
		maintaining a stream open for instance. No payload. */
		case nop = 0x4e /* "N" */
		
		/** The boolean value “true”. No payload. */
		case `true` = 0x54 /* "T" */
		
		/** The boolean value “false”. No payload. */
		case `false` = 0x46 /* "F" */
		
		/** An Int8 value. 1 byte payload. */
		case int8Bits = 0x69 /* "i" */
		
		/** A UInt8 value. 1 byte payload. */
		case uint8Bits = 0x55 /* "U" */
		
		/** An Int16 value. 2 bytes payload. */
		case int16Bits = 0x49 /* "I" */
		
		/** An Int32 value. 4 bytes payload. */
		case int32Bits = 0x6c /* "l" */
		
		/** An Int64 value. 8 bytes payload. */
		case int64Bits = 0x4c /* "L" */
		
		/** A Float with a 32-bit precision value. 4 bytes payload. */
		case float32Bits = 0x64 /* "d" */
		
		/** A Float with a 64-bit precision value. 8 bytes payload. */
		case float64Bits = 0x44 /* "D" */
		
		/** A high-precision number (string-encoded number). Size of string +
		string payload. */
		case highPrecisionNumber = 0x48 /* "H" */
		
		/** A char. 1 byte payload. */
		case char = 0x43 /* "C" */
		
		/** A string. Size of string + string payload. */
		case string = 0x53 /* "S" */
		
		case arrayStart = 0x5b /* "[" */
		case arrayEnd   = 0x5d /* "]" */
		
		case objectStart = 0x7b /* "{" */
		case objectEnd   = 0x7d /* "}" */
		
		case internalContainerType = 0x24 /* "$" */
		case internalContainerCount = 0x23 /* "#" */
		
	}
	
	private class func elementType(from simpleStream: SimpleStream, allowNop: Bool) throws -> UBJSONElementType {
		var curElementType: UBJSONElementType
		repeat {
			let intType: UInt8 = try simpleStream.readType()
			guard let e = UBJSONElementType(rawValue: intType) else {
				throw UBJSONSerializationError.invalidElementType(intType)
			}
			curElementType = e
		} while !allowNop && curElementType == .nop
		return curElementType
	}
	
	private class func highPrecisionNumber(from simpleStream: SimpleStream, options opt: ReadingOptions) throws -> HighPrecisionNumber {
		guard opt.contains(.allowHighPrecisionNumbers) else {throw UBJSONSerializationError.unexpectedHighPrecisionNumber}
		guard let n = intValue(from: try ubjsonObject(with: simpleStream, options: opt.union(.returnNopElements))) else {
			throw UBJSONSerializationError.malformedHighPrecisionNumber
		}
		let numberStrData = try simpleStream.readData(size: n, alwaysCopyBytes: false)
		guard let str = String(data: numberStrData, encoding: .utf8) else {
			/* We must copy the data (numberStrData is created without copying the bytes from the stream) */
			throw UBJSONSerializationError.invalidUTF8String(Data(numberStrData))
		}
		return try HighPrecisionNumber(unparsedValue: str)
	}
	
	private class func string(from simpleStream: SimpleStream, options opt: ReadingOptions) throws -> String {
		guard let n = intValue(from: try ubjsonObject(with: simpleStream, options: opt.union(.returnNopElements))) else {
			throw UBJSONSerializationError.malformedString
		}
		let strData = try simpleStream.readData(size: n, alwaysCopyBytes: false)
		guard let str = String(data: strData, encoding: .utf8) else {
			/* We must copy the data (numberStrData is created without copying the bytes from the stream) */
			throw UBJSONSerializationError.invalidUTF8String(Data(strData))
		}
		return str
	}
	
	private class func array(from simpleStream: SimpleStream, options opt: ReadingOptions) throws -> [Any?] {
		var res = [Any?]()
		let subParseOptWithNop = opt.union(.returnNopElements)
		
		var declaredObjectCount: Int?
		var curObj = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
		switch curObj {
		case .some(InternalUBJSONElement.containerType(let t)):
			guard let countType = try ubjsonObject(with: simpleStream, options: subParseOptWithNop) as? InternalUBJSONElement, case .containerCount(let c) = countType else {
				throw UBJSONSerializationError.malformedArray
			}
			switch t {
			case .null:    return [Any?](repeating: nil,   count: c)
			case .`true`:  return [Bool](repeating: true,  count: c)
			case .`false`: return [Bool](repeating: false, count: c)
				
			case .int8Bits:    let ret:   [Int8] = try simpleStream.readArrayOfType(count: c); return ret
			case .uint8Bits:   let ret:  [UInt8] = try simpleStream.readArrayOfType(count: c); return ret
			case .int16Bits:   let ret:  [Int16] = try simpleStream.readArrayOfType(count: c); return ret
			case .int32Bits:   let ret:  [Int32] = try simpleStream.readArrayOfType(count: c); return ret
			case .int64Bits:   let ret:  [Int64] = try simpleStream.readArrayOfType(count: c); return ret
			case .float32Bits: let ret:  [Float] = try simpleStream.readArrayOfType(count: c); return ret
			case .float64Bits: let ret: [Double] = try simpleStream.readArrayOfType(count: c); return ret
				
			case .highPrecisionNumber:
				return try (0..<c).map{ _ in try highPrecisionNumber(from: simpleStream, options: opt) }
				
			case .char:
				let charsAsInts: [Int8] = try simpleStream.readArrayOfType(count: c)
				return try charsAsInts.map{
					guard $0 >= 0 && $0 <= 127, let s = Unicode.Scalar(Int($0)) else {throw UBJSONSerializationError.invalidChar($0)}
					return Character(s)
				}
				
			case .string:
				return try (0..<c).map{ _ in try string(from: simpleStream, options: opt) }
				
			case .arrayStart:
				return try (0..<c).map{ _ in try array(from: simpleStream, options: opt) }
				
			case .objectStart:
				return try (0..<c).map{ _ in try object(from: simpleStream, options: opt) }
				
			case .nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount:
				fatalError()
			}
			fatalError()
			
		case .some(InternalUBJSONElement.containerCount(let c)):
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
			declaredObjectCount = c
			
		default: (/*nop*/)
		}
		
		var objectCount = 0
		while !isEndOfContainer(currentObjectCount: objectCount, declaredObjectCount: declaredObjectCount, currentObject: curObj, containerEnd: .arrayEnd) {
			switch curObj {
			case .some(_ as InternalUBJSONElement):
				/* Always an error as the arrayEnd case is detected earlier in
				 * the isEndOfContainer method */
				throw UBJSONSerializationError.malformedArray
				
			case .some(_ as Nop):
				if opt.contains(.keepNopElementsInArrays) {
					res.append(Nop.sharedNop)
				}
				
			default:
				res.append(curObj)
				objectCount += 1
			}
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
		}
		return res
	}
	
	private class func object(from simpleStream: SimpleStream, options opt: ReadingOptions) throws -> [String: Any?] {
		var res = [String: Any?]()
		let subParseOptNoNop = opt.subtracting(.returnNopElements)
		let subParseOptWithNop = opt.union(.returnNopElements)
		
		var declaredObjectCount: Int?
		var curObj = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
		switch curObj {
		case .some(InternalUBJSONElement.containerType(let t)):
			guard let countType = try ubjsonObject(with: simpleStream, options: subParseOptWithNop) as? InternalUBJSONElement, case .containerCount(let c) = countType else {
				throw UBJSONSerializationError.malformedObject
			}
			
			var ret = [String: Any?]()
			for _ in 0..<c {
				let k = try string(from: simpleStream, options: subParseOptNoNop)
				let v = try element(from: simpleStream, type: t, options: subParseOptNoNop)
				ret[k] = v
			}
			return ret
			
		case .some(InternalUBJSONElement.containerCount(let c)):
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
			declaredObjectCount = c
			
		case .some(_ as Nop):
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
			
		default: (/*nop*/)
		}
		
		var objectCount = 0
		while !isEndOfContainer(currentObjectCount: objectCount, declaredObjectCount: declaredObjectCount, currentObject: curObj, containerEnd: .objectEnd) {
			guard let key = curObj as? String else {throw UBJSONSerializationError.malformedObject}
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
			switch curObj {
			case .some(_ as InternalUBJSONElement):
				/* Always an error as the objectEnd case is detected earlier in
				 * the isEndOfContainer method */
				throw UBJSONSerializationError.malformedObject
				
			default:
				res[key] = curObj
				objectCount += 1
			}
			curObj = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
		}
		return res
	}
	
	private class func element(from simpleStream: SimpleStream, type elementType: UBJSONElementType, options opt: ReadingOptions) throws -> Any? {
		switch elementType {
		case .nop:
			assert(opt.contains(.returnNopElements))
			return Nop()
			
		case .null:    return nil
		case .`true`:  return true
		case .`false`: return false
			
		case .int8Bits:    let ret:   Int8 = try simpleStream.readType(); return ret
		case .uint8Bits:   let ret:  UInt8 = try simpleStream.readType(); return ret
		case .int16Bits:   let ret:  Int16 = try simpleStream.readType(); return ret
		case .int32Bits:   let ret:  Int32 = try simpleStream.readType(); return ret
		case .int64Bits:   let ret:  Int64 = try simpleStream.readType(); return ret
		case .float32Bits: let ret:  Float = try simpleStream.readType(); return ret
		case .float64Bits: let ret: Double = try simpleStream.readType(); return ret
			
		case .highPrecisionNumber:
			return try highPrecisionNumber(from: simpleStream, options: opt)
			
		case .char:
			let ci: Int8 = try simpleStream.readType()
			guard ci >= 0 && ci <= 127, let s = Unicode.Scalar(Int(ci)) else {throw UBJSONSerializationError.invalidChar(ci)}
			return Character(s)
			
		case .string:
			return try string(from: simpleStream, options: opt)
			
		case .arrayStart:
			return try array(from: simpleStream, options: opt)
			
		case .objectStart:
			return try object(from: simpleStream, options: opt)
			
		case .arrayEnd:  return InternalUBJSONElement.arrayEnd
		case .objectEnd: return InternalUBJSONElement.objectEnd
			
		case .internalContainerType:
			let invalidTypes: Set<UBJSONElementType> = [.nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount]
			let intContainerType: UInt8 = try simpleStream.readType()
			guard let containerType = UBJSONElementType(rawValue: intContainerType), !invalidTypes.contains(containerType) else {
				throw UBJSONSerializationError.invalidContainerType(intContainerType)
			}
			return InternalUBJSONElement.containerType(containerType)
			
		case .internalContainerCount:
			guard let n = intValue(from: try ubjsonObject(with: simpleStream, options: opt.union(.returnNopElements))) else {
				throw UBJSONSerializationError.malformedContainerCount
			}
			return InternalUBJSONElement.containerCount(n)
		}
	}
	
	private class func isEndOfContainer(currentObjectCount: Int, declaredObjectCount: Int?, currentObject: Any?, containerEnd: InternalUBJSONElement) -> Bool {
		if let declaredObjectCount = declaredObjectCount {
			assert(currentObjectCount <= declaredObjectCount)
			return currentObjectCount == declaredObjectCount
		} else {
			return currentObject == containerEnd
		}
	}
	
	private class func intValue(from ubjsonValue: Any?) -> Int? {
		switch ubjsonValue {
		case .some(let v as   Int): return v
		case .some(let v as  Int8): return Int(v)
		case .some(let v as UInt8): return Int(v)
		case .some(let v as Int16): return Int(v)
		case .some(let v as Int32): return Int(v)
		case .some(let v as Int64): return Int(v)
		default: return nil
		}
	}
	
}



private extension SimpleStream {
	
	func readArrayOfType<Type>(count: Int) throws -> [Type] {
		assert(MemoryLayout<Type>.stride == MemoryLayout<Type>.size)
		let data = try readData(size: count * MemoryLayout<Type>.size, alwaysCopyBytes: false)
		/* Thanks https://stackoverflow.com/a/24516400/1152894 */
		return data.withUnsafeBytes{ Array(UnsafeBufferPointer<Type>(start: $0, count: count)) }
	}
	
}
