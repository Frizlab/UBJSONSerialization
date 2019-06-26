/*
 * UBJSONSpec8Serialization.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 6/24/19.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import SimpleStream



/** [UBJSON spec 8](https://github.com/ubjson/universal-binary-json/tree/b0f2cbb44ef19357418e41a0813fc498a9eb2779/spec8)

These specs are obsoleted by version 12. */
final public class UBJSONSpec8Serialization {
	
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
		array of indeterminate size (Nop is invalid in an array whose size is
		known). Specs says this element is a valueless value, so in array, it
		should simply be skipped: for this input, `["a", Nop, "b"]`, we should
		return `["a", "b"]`. This option allows you to keep the `Nop` in the
		deserialized array.
		
		`Nop` in a dictionary has no meaning and is always **skipped** for
		indeterminate size dictionaries (Nop is invalid in a dictionary whose size
		is known). */
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
		
		/**
		Removes `No-op` elements from arrays. For dictionaries, the Nop element is
		invalid as it is a valueless value.
		
		- Note: This option is expensive (has to do a first pass through the whole
		serialized object graph before serialization). Only use it in case there
		is a chance your data contains `No-op` elements and you want it dropped. */
		public static let skipNopElementsInArrays = WritingOptions(rawValue: 1 << 2)
		
		/**
		Declare the containers to have an unknown size in the serialized data.
		Mostly useful if we want to implement proper streaming support later. */
		public static let declareContainerWithUnknownSize = WritingOptions(rawValue: 1 << 3)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public class func ubjsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any? {
		let simpleDataStream = SimpleDataStream(data: data)
		let ret = try ubjsonObject(with: simpleDataStream, options: opt)
		
		/* Check for no garbage at end of the data */
		let endOfData = try simpleDataStream.readDataToEnd()
		guard endOfData.first(where: { $0 != UBJSONSpec8ElementType.nop.rawValue }) == nil else {throw UBJSONSerializationError.garbageAtEnd}
		
		return ret
	}
	
	public class func ubjsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> Any? {
		let simpleInputStream = SimpleInputStream(stream: stream, bufferSize: 1024*1024, bufferSizeIncrement: 1024, streamReadSizeLimit: nil)
		return try ubjsonObject(with: simpleInputStream, options: opt)
	}
	
	/* Note: We're using the SimpleReadStream method instead of InputStream for
	 *       conveninence, but using InputStream directly would probably be
	 *       faster. Also we don't need all of the “clever” bits of SimpleStream,
	 *       so one day we should migrate, or at least measure the performances
	 *       of both. */
	class func ubjsonObject(with simpleStream: SimpleReadStream, options opt: ReadingOptions = []) throws -> Any? {
		/* We assume Swift will continue to use the IEEE 754 spec for representing
		 * floats and doubles forever. Use of the spec validated in August 2017
		 * by @jckarter: https://twitter.com/jckarter/status/900073525905506304 */
		precondition(Int.max == Int64.max, "I currently need Int to be Int64")
		precondition(MemoryLayout<Float>.size == 4, "I currently need Float to be 32 bits")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
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
			
		case let i as   Int: size += try write(int:  i, to: stream, options: opt)
		case var i as  Int8: size += try write(int: &i, to: stream, options: opt)
		case var i as Int16: size += try write(int: &i, to: stream, options: opt)
		case var i as Int32: size += try write(int: &i, to: stream, options: opt)
		case var i as Int64: size += try write(int: &i, to: stream, options: opt)
			
		case var f as Float:
			size += try write(elementType: .float32Bits, toStream: stream)
			size += try stream.write(value: &f)
			
		case var d as Double:
			size += try write(elementType: .float64Bits, toStream: stream)
			size += try stream.write(value: &d)
			
		case let h as HighPrecisionNumber:
			let strValue = opt.contains(.normalizeHighPrecisionNumbers) ? h.normalizedStringValue : h.stringValue
			size += try write(string: strValue, shortStringMarker: .highPrecisionNumberSizeOn1Byte, longStringMarker: .highPrecisionNumberSizeOn4Bytes, to: stream, options: opt)
			
		case let s as String:
			size += try write(string: s, shortStringMarker: .stringSizeOn1Byte, longStringMarker: .stringSizeOn4Bytes, to: stream, options: opt)
			
		case let a as [Any?]:
			size += try write(array: a, to: stream, options: opt)
			
		case let o as [String: Any?]:
			size += try write(object: o, to: stream, options: opt)
			
		case let unknown?:
			throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: unknown)
		}
		return size
	}
	
	/** Check a dictionary for UBJSON validity.
	
	You have an option to treat Nop as an invalid value, either if directly the
	value, or if it inside an array. Nop is always invalid inside a dictionary. */
	public class func isValidUBJSONObject(_ obj: Any?, treatNopAsInvalid: Bool = false, treatNopAsInvalidInArray: Bool = false) -> Bool {
		switch obj {
		case nil:                                                return true
		case _ as Nop:                                           return treatNopAsInvalid
		case _ as Bool, _ as Int, _ as Int8:                     return true
		case _ as Int16, _ as Int32, _ as Int64, _ as Float:     return true
		case _ as Double, _ as HighPrecisionNumber, _ as String: return true
			
		case let a as         [Any?]: return !a.contains(where: { !isValidUBJSONObject($0,       treatNopAsInvalid: treatNopAsInvalidInArray, treatNopAsInvalidInArray: treatNopAsInvalidInArray) })
		case let o as [String: Any?]: return !o.contains(where: { !isValidUBJSONObject($0.value, treatNopAsInvalid: true,                     treatNopAsInvalidInArray: treatNopAsInvalidInArray) })
			
		default:
			return false
		}
	}
	
	/** Check both given UBJSON for equality. Throws if the docs are not valid
	UBJSON docs! */
	public class func areUBJSONDocEqual(_ doc1: Any?, _ doc2: Any?) throws -> Bool {
		switch doc1 {
		case nil:             guard doc2          == nil else {return false}
		case let val as Bool: guard doc2 as? Bool == val else {return false}
			
		case _ as Nop: guard doc2 is Nop else {return false}
			
		case let val1 as Int8:
			guard doc2 as? Int8 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int8>.size, let val2 = doc2 as? Int, val1 == Int8(val2) {return true}
				return false
			}
			
		case let val1 as Int16:
			guard doc2 as? Int16 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int16>.size, let val2 = doc2 as? Int, val1 == Int16(val2) {return true}
				return false
			}
			
		case let val1 as Int32:
			guard doc2 as? Int32 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int32>.size, let val2 = doc2 as? Int, val1 == Int32(val2) {return true}
				return false
			}
			
		case let val1 as Int64:
			guard doc2 as? Int64 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int64>.size, let val2 = doc2 as? Int, val1 == Int64(val2) {return true}
				return false
			}
			
		case let val1 as Int:
			guard doc2 as? Int == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<Int8>.size,  let val2 = doc2 as? Int8,  val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int16>.size, let val2 = doc2 as? Int16, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int32>.size, let val2 = doc2 as? Int32, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int64>.size, let val2 = doc2 as? Int64, val1 == Int(val2) {return true}
				return false
			}
			
		case let val as Float:  guard doc2 as? Float  == val else {return false}
		case let val as Double: guard doc2 as? Double == val else {return false}
		case let str as String: guard doc2 as? String == str else {return false}
		case let val as HighPrecisionNumber: guard doc2 as? HighPrecisionNumber == val else {return false}
			
		case let subObj1 as [String: Any?]:
			guard let subObj2 = doc2 as? [String: Any?], subObj1.count == subObj2.count else {return false}
			for (subval1, subval2) in zip(subObj1.sorted(by: { $0.key < $1.key }), subObj2.sorted(by: { $0.key < $1.key })) {
				guard subval1.key == subval2.key else {return false}
				guard try areUBJSONDocEqual(subval1.value, subval2.value) else {return false}
			}
			
		case let array1 as [Any?]:
			guard let array2 = doc2 as? [Any?], array1.count == array2.count else {return false}
			for (subval1, subval2) in zip(array1, array2) {
				guard try areUBJSONDocEqual(subval1, subval2) else {return false}
			}
			
		case let unknown?:
			throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: unknown)
		}
		
		return true
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum InternalUBJSONElement : Equatable {
		
		case containerEnd
		
		static func !=(lhs: Any?, rhs: InternalUBJSONElement) -> Bool {
			guard let lhs = lhs as? InternalUBJSONElement else {return true}
			return lhs != rhs
		}
		
	}
	
	/** The recognized UBJSON element types. */
	private enum UBJSONSpec8ElementType : UInt8 {
		
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
		case int8Bits = 0x42 /* "B" */
		
		/** An Int16 value. 2 bytes payload. */
		case int16Bits = 0x69 /* "i" */
		
		/** An Int32 value. 4 bytes payload. */
		case int32Bits = 0x49 /* "I" */
		
		/** An Int64 value. 8 bytes payload. */
		case int64Bits = 0x4c /* "L" */
		
		/** A Float with a 32-bit precision value. 4 bytes payload. */
		case float32Bits = 0x64 /* "d" */
		
		/** A Float with a 64-bit precision value. 8 bytes payload. */
		case float64Bits = 0x44 /* "D" */
		
		/** A high-precision number (string-encoded number). Size of string on 1
		byte + string payload. */
		case highPrecisionNumberSizeOn1Byte = 0x68 /* "h" */
		
		/** A high-precision number (string-encoded number). Size of string on 4
		byte4 + string payload. */
		case highPrecisionNumberSizeOn4Bytes = 0x48 /* "H" */
		
		/** A string. Size of string on 1 byte + string payload. */
		case stringSizeOn1Byte = 0x73 /* "s" */
		
		/** A string. Size of string on 4 bytes + string payload. */
		case stringSizeOn4Bytes = 0x53 /* "S" */
		
		case arrayStartSizeOn1Byte  = 0x61 /* "a" */
		case arrayStartSizeOn4Bytes = 0x41 /* "A" */
		
		case objectStartSizeOn1Byte  = 0x6f /* "o" */
		case objectStartSizeOn4Bytes = 0x4f /* "O" */
		
		case containerEnd = 0x45 /* "E" */
		
	}
	
	private class func elementType(from simpleStream: SimpleReadStream, allowNop: Bool) throws -> UBJSONSpec8ElementType {
		var curElementType: UBJSONSpec8ElementType
		repeat {
			let intType: UInt8 = try simpleStream.readBigEndianInt()
			guard let e = UBJSONSpec8ElementType(rawValue: intType) else {
				throw UBJSONSerializationError.invalidElementType(intType)
			}
			curElementType = e
		} while !allowNop && curElementType == .nop
		return curElementType
	}
	
	private class func highPrecisionNumber(from simpleStream: SimpleReadStream, isSmall: Bool, options opt: ReadingOptions) throws -> HighPrecisionNumber {
		guard opt.contains(.allowHighPrecisionNumbers) else {throw UBJSONSerializationError.unexpectedHighPrecisionNumber}
		let str = try string(from: simpleStream, isSmall: isSmall, options: opt)
		return try HighPrecisionNumber(unparsedValue: str)
	}
	
	private class func string(from simpleStream: SimpleReadStream, isSmall: Bool, options opt: ReadingOptions) throws -> String {
		let size: Int
		if isSmall {let s: Int8  = try simpleStream.readBigEndianInt(); size = Int(s)}
		else       {let s: Int32 = try simpleStream.readBigEndianInt(); size = Int(s)}
		
		let strData = try simpleStream.readData(size: size)
		guard let str = String(data: strData, encoding: .utf8) else {
			throw UBJSONSerializationError.invalidUTF8String(strData)
		}
		return str
	}
	
	private class func array(from simpleStream: SimpleReadStream, isSmall: Bool, options opt: ReadingOptions) throws -> [Any?] {
		var res = [Any?]()
		
		let size: Int
		if isSmall {let s: UInt8  = try simpleStream.readBigEndianInt(); size = Int(s)}
		else       {let s: UInt32 = try simpleStream.readBigEndianInt(); size = Int(s)}
		
		let isIndeterminateSize = (isSmall && size == 255)
		if !isIndeterminateSize {
			let subParseOptWithNop = opt.union(.returnNopElements)
			for _ in 0..<size {
				let curObj = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
				guard !(curObj is Nop) else {throw UBJSONSerializationError.sizedArrayContainsNop}
				guard curObj != InternalUBJSONElement.containerEnd else {throw UBJSONSerializationError.malformedObject}
				
				res.append(curObj)
			}
		} else {
			let subParseOpt = opt.contains(.keepNopElementsInArrays) ? opt.union(.returnNopElements) : opt.subtracting(.returnNopElements)
			while true {
				let curObj = try ubjsonObject(with: simpleStream, options: subParseOpt)
				guard curObj != InternalUBJSONElement.containerEnd else {break}
				res.append(curObj) /* Nop filtering is done before */
			}
		}
		
		return res
	}
	
	private class func object(from simpleStream: SimpleReadStream, isSmall: Bool, options opt: ReadingOptions) throws -> [String: Any?] {
		var res = [String: Any?]()
		
		let size: Int
		if isSmall {let s: UInt8  = try simpleStream.readBigEndianInt(); size = Int(s)}
		else       {let s: UInt32 = try simpleStream.readBigEndianInt(); size = Int(s)}
		
		let isIndeterminateSize = (isSmall && size == 255)
		if !isIndeterminateSize {
			let subParseOptWithNop = opt.union(.returnNopElements)
			for _ in 0..<size {
				let curKeyAny = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
				guard let curKey = curKeyAny as? String else {throw UBJSONSerializationError.malformedObject}
				
				let curValue = try ubjsonObject(with: simpleStream, options: subParseOptWithNop)
				if curValue is Nop {throw UBJSONSerializationError.malformedObject}
				
				res[curKey] = curValue
			}
		} else {
			let subParseOptNoNop = opt.subtracting(.returnNopElements)
			while true {
				let curKeyAny = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
				guard curKeyAny != InternalUBJSONElement.containerEnd else {break}
				guard let curKey = curKeyAny as? String else {throw UBJSONSerializationError.malformedObject}
				
				let curValue = try ubjsonObject(with: simpleStream, options: subParseOptNoNop)
				guard curValue != InternalUBJSONElement.containerEnd else {throw UBJSONSerializationError.malformedObject}
				
				res[curKey] = curValue /* Nop filtering is done before */
			}
		}
		
		return res
	}
	
	private class func element(from simpleStream: SimpleReadStream, type elementType: UBJSONSpec8ElementType, options opt: ReadingOptions) throws -> Any? {
		switch elementType {
		case .nop:
			assert(opt.contains(.returnNopElements))
			return Nop()
			
		case .null:    return nil
		case .`true`:  return true
		case .`false`: return false
			
		case .int8Bits:    let ret:   Int8 = try simpleStream.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int16Bits:   let ret:  Int16 = try simpleStream.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int32Bits:   let ret:  Int32 = try simpleStream.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int64Bits:   let ret:  Int64 = try simpleStream.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .float32Bits: let ret:  Float = try simpleStream.readType(); return ret
		case .float64Bits: let ret: Double = try simpleStream.readType(); return ret
			
		case .highPrecisionNumberSizeOn1Byte:  return try highPrecisionNumber(from: simpleStream, isSmall: true,  options: opt)
		case .highPrecisionNumberSizeOn4Bytes: return try highPrecisionNumber(from: simpleStream, isSmall: false, options: opt)
			
		case .stringSizeOn1Byte:  return try string(from: simpleStream, isSmall: true,  options: opt)
		case .stringSizeOn4Bytes: return try string(from: simpleStream, isSmall: false, options: opt)
			
		case .arrayStartSizeOn1Byte:  return try array(from: simpleStream, isSmall: true,  options: opt)
		case .arrayStartSizeOn4Bytes: return try array(from: simpleStream, isSmall: false, options: opt)
			
		case .objectStartSizeOn1Byte:  return try object(from: simpleStream, isSmall: true,  options: opt)
		case .objectStartSizeOn4Bytes: return try object(from: simpleStream, isSmall: false, options: opt)
			
		case .containerEnd: return InternalUBJSONElement.containerEnd
		}
	}
	
	/** Determine whether the end of the container has been reached with a given
	set of parameter.
	
	If the declared object count is nil (was not declared in the container), the
	current object must not be nil. (Can be .some(nil), though!) */
	private class func isEndOfContainer(currentObjectCount: Int, declaredObjectCount: Int?, currentObject: Any??) -> Bool {
		if let declaredObjectCount = declaredObjectCount {
			assert(currentObjectCount <= declaredObjectCount)
			return currentObjectCount == declaredObjectCount
		} else {
			return currentObject! as? InternalUBJSONElement == InternalUBJSONElement.containerEnd
		}
	}
	
	private class func intValue(from ubjsonValue: Any?) -> Int? {
		switch ubjsonValue {
		case .some(let v as   Int): return v
		case .some(let v as  Int8): return Int(v)
		case .some(let v as Int16): return Int(v)
		case .some(let v as Int32): return Int(v)
		case .some(let v as Int64): return Int(v)
		default: return nil
		}
	}
	
	private class func write(elementType: UBJSONSpec8ElementType, toStream stream: OutputStream) throws -> Int {
		var t = elementType.rawValue
		return try stream.write(value: &t)
	}
	
	private class func write(string s: String, shortStringMarker: UBJSONSpec8ElementType, longStringMarker: UBJSONSpec8ElementType, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		let data = Data(s.utf8)
		if data.count <= 254 {
			var sizeInt8 = Int8(data.count)
			size += try write(elementType: shortStringMarker, toStream: stream)
			size += try stream.write(value: &sizeInt8)
		} else {
			var sizeInt32 = Int32(data.count)
			size += try write(elementType: longStringMarker, toStream: stream)
			size += try stream.write(value: &sizeInt32)
		}
		try data.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
		return size
	}
	
	private class func write(int i: inout Int8, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		size += try write(elementType: .int8Bits, toStream: stream)
		size += try stream.write(value: &i)
		return size
	}
	
	private class func write(int i: inout Int16, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		guard opt.contains(.optimizeIntsForSize) else {
			var size = 0
			size += try write(elementType: .int16Bits, toStream: stream)
			size += try stream.write(value: &i)
			return size
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int8.min && i <= Int8.max {var i =  Int8(i); return try write(int: &i, to: stream, options: opt)}
		else                              {                  return try write(int: &i, to: stream, options: optNoOptim)}
	}
	
	private class func write(int i: inout Int32, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		guard opt.contains(.optimizeIntsForSize) else {
			var size = 0
			size += try write(elementType: .int32Bits, toStream: stream)
			size += try stream.write(value: &i)
			return size
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int16.min && i <= Int16.max {var i = Int16(i); return try write(int: &i, to: stream, options: opt)}
		else                                {                  return try write(int: &i, to: stream, options: optNoOptim)}
	}
	
	private class func write(int i: inout Int64, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		guard opt.contains(.optimizeIntsForSize) else {
			var size = 0
			size += try write(elementType: .int64Bits, toStream: stream)
			size += try stream.write(value: &i)
			return size
		}
		
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		if i >= Int32.min && i <= Int32.max {var i = Int32(i); return try write(int: &i, to: stream, options: opt)}
		else                                {                  return try write(int: &i, to: stream, options: optNoOptim)}
	}
	
	private class func write(int i: Int, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		let optNoOptim = opt.subtracting(.optimizeIntsForSize)
		
		/* We check all the sizes directly in the method for the Int case (as
		 * opposed to the Int64 case for instance where the Int32 case is checked,
		 * but the Int16 case is checked in the Int32 function).
		 *
		 * The Int case is most likely to be the most common, so we want it to be
		 * as straightforward and fast as possible. */
		
		if      i >=  Int8.min && i <=  Int8.max {var i =  Int8(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else if i >= Int16.min && i <= Int16.max {var i = Int16(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else if i >= Int32.min && i <= Int32.max {var i = Int32(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else                                     {var i = Int64(i); return try write(int: &i, to: stream, options: optNoOptim)}
	}
	
	private class func write(array a: [Any?], to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		
		let isIndeterminateSize = opt.contains(.declareContainerWithUnknownSize)
		
		let optNoSkipNop = opt.subtracting(.skipNopElementsInArrays)
		let a = !(opt.contains(.skipNopElementsInArrays) && isIndeterminateSize) ? a : dropNopRecursively(element: a) as! [Any?]
		
		if isIndeterminateSize {
			var s: UInt8 = 255
			size += try write(elementType: .arrayStartSizeOn1Byte, toStream: stream)
			size += try stream.write(value: &s)
		} else {
			let c = a.count
			if c <= 254 {
				var s = UInt8(c)
				size += try write(elementType: .arrayStartSizeOn1Byte, toStream: stream)
				size += try stream.write(value: &s)
			} else {
				var s = UInt32(c)
				size += try write(elementType: .arrayStartSizeOn4Bytes, toStream: stream)
				size += try stream.write(value: &s)
			}
		}
		
		for e in a {
			if !isIndeterminateSize && e is Nop {throw UBJSONSerializationError.sizedArrayContainsNop}
			size += try writeUBJSONObject(e, to: stream, options: optNoSkipNop)
		}
		if isIndeterminateSize {size += try write(elementType: .containerEnd, toStream: stream)}
		
		return size
	}
	
	private class func write(object o: [String: Any?], to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		
		let isIndeterminateSize = opt.contains(.declareContainerWithUnknownSize)
		if isIndeterminateSize {
			var s: UInt8 = 255
			size += try write(elementType: .arrayStartSizeOn1Byte, toStream: stream)
			size += try stream.write(value: &s)
		} else {
			let c = o.count
			if c <= 254 {
				var s = UInt8(c)
				size += try write(elementType: .arrayStartSizeOn1Byte, toStream: stream)
				size += try stream.write(value: &s)
			} else {
				var s = UInt32(c)
				size += try write(elementType: .arrayStartSizeOn4Bytes, toStream: stream)
				size += try stream.write(value: &s)
			}
		}
		
		for (k, v) in o {
			guard !(v is Nop) else {throw UBJSONSerializationError.dictionaryContainsNop}
			size += try write(string: k, shortStringMarker: .stringSizeOn1Byte, longStringMarker: .stringSizeOn4Bytes, to: stream, options: opt)
			size += try writeUBJSONObject(v, to: stream, options: opt)
		}
		if isIndeterminateSize {size += try write(elementType: .containerEnd, toStream: stream)}
		
		return size
	}
	
	private class func dropNopRecursively(element e: Any?, fromDictionary: Bool = false) -> Any?? {
		/* We keep the Nop element in values of a dictionary to have explicit
		 * serialization failure later (Nop is forbidden in a dictionary). */
		if !fromDictionary && e is Nop {return nil}
		
		if let a = e as? [Any?]         {return .some(a.compactMap{ dropNopRecursively(element: $0, fromDictionary: false) })}
		if let o = e as? [String: Any?] {return .some(o.mapValues{  dropNopRecursively(element: $0, fromDictionary: true)! })} /* We can bang because nil is never return when we come from a dictionary. */
		return .some(e)
	}
	
	private class func int8(from o: Any) -> Int8 {
		switch o {
		case let i as Int8:  return i
		case let i as Int16: return Int8(i)
		case let i as Int32: return Int8(i)
		case let i as Int64: return Int8(i)
		case let i as Int:   return Int8(i)
		default: fatalError("Invalid object to convert to int8: \(o)")
		}
	}
	
	private class func int16(from o: Any) -> Int16 {
		switch o {
		case let i as Int8:  return Int16(i)
		case let i as Int16: return i
		case let i as Int32: return Int16(i)
		case let i as Int64: return Int16(i)
		case let i as Int:   return Int16(i)
		default: fatalError("Invalid object to convert to int16: \(o)")
		}
	}
	
	private class func int32(from o: Any) -> Int32 {
		switch o {
		case let i as Int8:  return Int32(i)
		case let i as Int16: return Int32(i)
		case let i as Int32: return i
		case let i as Int64: return Int32(i)
		case let i as Int:   return Int32(i)
		default: fatalError("Invalid object to convert to int32: \(o)")
		}
	}
	
	private class func int64(from o: Any) -> Int64 {
		switch o {
		case let i as Int8:  return Int64(i)
		case let i as Int16: return Int64(i)
		case let i as Int32: return Int64(i)
		case let i as Int64: return i
		case let i as Int:   return Int64(i)
		default: fatalError("Invalid object to convert to int64: \(o)")
		}
	}
	
}



private extension SimpleReadStream {
	
	func readArrayOfType<Type>(count: Int) throws -> [Type] {
		assert(MemoryLayout<Type>.stride == MemoryLayout<Type>.size)
		/* Adapted (and upgraded) from https://stackoverflow.com/a/24516400 */
		return try readData(size: count * MemoryLayout<Type>.size, { bytes in
			let bound = bytes.bindMemory(to: Type.self)
			return Array(bound)
		})
	}
	
}
