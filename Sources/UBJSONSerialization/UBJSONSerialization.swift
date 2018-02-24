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
		Do not convert Int8, Int16, etc. to Int. */
		public static let keepIntPrecision = ReadingOptions(rawValue: 1 << 0)
		
		/**
		Allow high-precision numbers (numbers formatted as Strings). Will be
		returned as HighPrecisionNumber, which is basically a wrapper for the
		string-encoded value.
		
		The serialization will make sure the returned wrapped string is a valid
		high-precision number (follows the [JSON number spec](http://json.org)).
		
		You can use something like [BigInt](https://github.com/lorentey/BigInt) to
		handle big integers. Note high-precision numbers can also be decimals. */
		public static let allowHighPrecisionNumbers = ReadingOptions(rawValue: 1 << 1)
		
		/**
		Allows returning the `Nop` deserialized object. By default the `No-Op`
		element is skipped when deserializing UBJSON.
		
		Note this applies only to `No-Op` elements at the root of the UBJSON
		document being deserialized. For embedded `No-Op`s, see
		`.keepNopElementsInArrays`. */
		public static let returnNopElements = ReadingOptions(rawValue: 1 << 2)
		
		/**
		Return `Nop` objects when receiving the serialized `No-Op` element in an
		array. Specs says this element is a valueless value, so in array, it
		should simply be skipped: for this input, `["a", Nop, "b"]`, we should
		return `["a", "b"]`. This option allows you to keep the `Nop` in the
		deserialized array. */
		public static let keepNopElementsInArrays = ReadingOptions(rawValue: 1 << 3)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public struct WritingOptions : OptionSet {
		
		public let rawValue: Int
		
		/**
		Normalize the representation of high precisions numbers before
		serialization. See the doc of HighPrecisionNumber for more information
		about normalization. */
		public static let normalizeHighPrecisionNumbers = WritingOptions(rawValue: 1 << 0)
		
		/**
		Find the smallest representation possible for the serialization of an int.
		
		- Note: This option is always on for `Int` objects. It has to be
		specifically asked only for other ints types (`Int8`, `Int16`, etc.) */
		public static let optimizeIntsForSize = WritingOptions(rawValue: 1 << 1)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public class func ubjsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any? {
		let simpleDataStream = SimpleDataStream(data: data)
		let ret = try ubjsonObject(with: simpleDataStream, options: opt)
		
		/* Check for no garbage at end of the data */
		let endOfData = try simpleDataStream.readDataToEnd(alwaysCopyBytes: false)
		guard endOfData.filter({ $0 != UBJSONElementType.nop.rawValue }).count == 0 else {throw UBJSONSerializationError.garbageAtEnd}
		
		return ret
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
		precondition(Int.max == Int64.max, "I currently need Int to be Int64")
		precondition(MemoryLayout<Float>.size == 4, "I currently need Float to be 32 bits")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		/* TODO: Handle endianness! UBSJON is big endian. */
		
		let elementType = try self.elementType(from: simpleStream, allowNop: opt.contains(.returnNopElements))
		return try element(from: simpleStream, type: elementType, options: opt)
	}
	
	public class func data(withUBJSONObject object: Any?, options opt: WritingOptions = []) throws -> Data {
		let stream = OutputStream(toMemory: ())
		stream.open(); defer {stream.close()}
		
		_ = try writeUBJSONObject(object, to: stream, options: opt)
		guard let nsdata = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? NSData else {
			throw UBJSONSerializationError.internalError
		}
		
		return Data(referencing: nsdata)
	}
	
	public class func writeUBJSONObject(_ object: Any?, to stream: OutputStream, options opt: WritingOptions = []) throws -> Int {
		precondition(Int.max == Int64.max, "I currently need Int to be Int64")
		precondition(MemoryLayout<Float>.size == 4, "I currently need Float to be 32 bits")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		var size = 0
		switch object {
		case nil:                    size += try write(elementType: .null, toStream: stream)
		case _ as Nop:               size += try write(elementType: .nop, toStream: stream)
		case let b as Bool where  b: size += try write(elementType: .`true`, toStream: stream)
		case let b as Bool where !b: size += try write(elementType: .`false`, toStream: stream)
			
		case var i as   Int: try write(int: &i, to: stream, options: opt, size: &size)
		case var i as  Int8: try write(int: &i, to: stream, options: opt, size: &size)
		case var i as UInt8: try write(int: &i, to: stream, options: opt, size: &size)
		case var i as Int16: try write(int: &i, to: stream, options: opt, size: &size)
		case var i as Int32: try write(int: &i, to: stream, options: opt, size: &size)
		case var i as Int64: try write(int: &i, to: stream, options: opt, size: &size)
			
		case var f as Float:
			size += try write(elementType: .float32Bits, toStream: stream)
			size += try write(value: &f, toStream: stream)
			
		case var d as Double:
			size += try write(elementType: .float64Bits, toStream: stream)
			size += try write(value: &d, toStream: stream)
			
		case let h as HighPrecisionNumber:
			let strValue = opt.contains(.normalizeHighPrecisionNumbers) ? h.normalizedStringValue : h.stringValue
			size += try write(elementType: .highPrecisionNumber, toStream: stream)
			size += try writeUBJSONObject(strValue, to: stream, options: opt)
			
		case let c as Character:
			guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first, s.value >= 0 && s.value <= 127 else {
				throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: c)
			}
			
			var v: Int8 = Int8(s.value)
			size += try write(elementType: .char, toStream: stream)
			size += try write(value: &v, toStream: stream)
			
		case let s as String:
			let data = Data(s.utf8)
			size += try write(elementType: .string, toStream: stream)
			size += try writeUBJSONObject(data.count, to: stream, options: opt)
			data.withUnsafeBytes{ ptr in size += stream.write(ptr, maxLength: data.count) }
			
		case let a as [Any?]:
			let warning = "todo (optimized formats)"
			size += try write(elementType: .arrayStart, toStream: stream)
			for e in a {size += try writeUBJSONObject(e, to: stream, options: opt)}
			size += try write(elementType: .arrayEnd, toStream: stream)
			
		case let o as [String: Any?]:
			let warning = "todo (optimized formats)"
			size += try write(elementType: .objectStart, toStream: stream)
			for (k, v) in o {
				size += try writeUBJSONObject(k, to: stream, options: opt)
				size += try writeUBJSONObject(v, to: stream, options: opt)
			}
			size += try write(elementType: .objectEnd, toStream: stream)
			
		default:
			throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: object! /* nil case already processed above */)
		}
		return size
	}
	
	public class func isValidUBJSONObject(_ obj: Any?) -> Bool {
		switch obj {
		case nil:                                                  return true
		case _ as Bool, _ as Nop, _ as Int, _ as Int8, _ as UInt8: return true
		case _ as Int16, _ as Int32, _ as Int64, _ as Float:       return true
		case _ as Double, _ as HighPrecisionNumber, _ as String:   return true
			
		case let c as Character:
			guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first else {return false}
			guard s.value >= 0 && s.value <= 127 else {return false}
			return true
			
		case let a as         [Any?]: return !a.contains(where: { !isValidUBJSONObject($0) })
		case let o as [String: Any?]: return !o.contains(where: { !isValidUBJSONObject($0.value) })
			
		default:
			return false
		}
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
		let str = try string(from: simpleStream, options: opt, forcedMalformedError: .malformedHighPrecisionNumber)
		return try HighPrecisionNumber(unparsedValue: str)
	}
	
	private class func string(from simpleStream: SimpleStream, options opt: ReadingOptions, forcedMalformedError: UBJSONSerializationError? = nil) throws -> String {
		guard let n = intValue(from: try ubjsonObject(with: simpleStream, options: opt.union(.returnNopElements))) else {
			throw forcedMalformedError ?? UBJSONSerializationError.malformedString
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
				
			case .int8Bits:    let ret:   [Int8] = try simpleStream.readArrayOfType(count: c); return opt.contains(.keepIntPrecision) ? ret : ret.map{ Int($0) }
			case .uint8Bits:   let ret:  [UInt8] = try simpleStream.readArrayOfType(count: c); return opt.contains(.keepIntPrecision) ? ret : ret.map{ Int($0) }
			case .int16Bits:   let ret:  [Int16] = try simpleStream.readArrayOfType(count: c); return opt.contains(.keepIntPrecision) ? ret : ret.map{ Int($0) }
			case .int32Bits:   let ret:  [Int32] = try simpleStream.readArrayOfType(count: c); return opt.contains(.keepIntPrecision) ? ret : ret.map{ Int($0) }
			case .int64Bits:   let ret:  [Int64] = try simpleStream.readArrayOfType(count: c); return opt.contains(.keepIntPrecision) ? ret : ret.map{ Int($0) }
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
			
		case .int8Bits:    let ret:   Int8 = try simpleStream.readType(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .uint8Bits:   let ret:  UInt8 = try simpleStream.readType(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int16Bits:   let ret:  Int16 = try simpleStream.readType(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int32Bits:   let ret:  Int32 = try simpleStream.readType(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int64Bits:   let ret:  Int64 = try simpleStream.readType(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
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
	
	private class func write<T>(value: inout T, toStream stream: OutputStream) throws -> Int {
		let size = MemoryLayout<T>.size
		guard size > 0 else {return 0} /* Less than probable that size is equal to zero... */
		
		return try withUnsafePointer(to: &value){ pointer -> Int in
			return try pointer.withMemoryRebound(to: UInt8.self, capacity: size, { bytes -> Int in
				let writtenSize = stream.write(bytes, maxLength: size)
				guard size == writtenSize else {throw UBJSONSerializationError.cannotWriteToStream(streamError: stream.streamError)}
				return size
			})
		}
	}
	
	private class func write(elementType: UBJSONElementType, toStream stream: OutputStream) throws -> Int {
		var t = elementType.rawValue
		return try write(value: &t, toStream: stream)
	}
	
	private class func write(int i: inout Int8, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		size += try write(elementType: .int8Bits, toStream: stream)
		size += try write(value: &i, toStream: stream)
	}
	
	private class func write(int i: inout UInt8, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		size += try write(elementType: .uint8Bits, toStream: stream)
		size += try write(value: &i, toStream: stream)
	}
	
	private class func write(int i: inout Int16, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		guard opt.contains(.optimizeIntsForSize) else {
			size += try write(elementType: .int16Bits, toStream: stream)
			size += try write(value: &i, toStream: stream)
			return
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int8.min && i <= Int8.max {
			var i = Int8(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else if i >= UInt8.min && i <= UInt8.max {
			var i = UInt8(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else {
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		}
	}
	
	private class func write(int i: inout Int32, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		guard opt.contains(.optimizeIntsForSize) else {
			size += try write(elementType: .int32Bits, toStream: stream)
			size += try write(value: &i, toStream: stream)
			return
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int16.min && i <= Int16.max {
			var i = Int16(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else {
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		}
	}
	
	private class func write(int i: inout Int64, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		guard opt.contains(.optimizeIntsForSize) else {
			size += try write(elementType: .int32Bits, toStream: stream)
			size += try write(value: &i, toStream: stream)
			return
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int32.min && i <= Int32.max {
			var i = Int32(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else {
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		}
	}
	
	private class func write(int i: inout Int, to stream: OutputStream, options opt: WritingOptions, size: inout Int) throws {
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		/* We check all the sizes directly in the method for the Int case (as
		 * opposed to the Int64 case for instance where the Int32 case is checked,
		 * but the Int16 case is checked in the Int32 function).
		 *
		 * The Int case is most likely to be the most common, so we want it to be
		 * as straightforward and fast as possible. */
		
		if i >= Int8.min && i <= Int8.max {
			var i = Int8(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else if i >= UInt8.min && i <= UInt8.max {
			var i = UInt8(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else if i >= Int16.min && i <= Int16.max {
			var i = Int16(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else if i >= Int32.min && i <= Int32.max {
			var i = Int32(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
		} else {
			var i = Int64(i)
			try write(int: &i, to: stream, options: optNoOptim, size: &size)
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
