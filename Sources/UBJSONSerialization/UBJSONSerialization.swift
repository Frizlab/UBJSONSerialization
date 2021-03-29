/*
 * UBJSONSerialization.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation

import StreamReader



/**
[UBJSON spec 12](https://github.com/ubjson/universal-binary-json/tree/b0f2cbb44ef19357418e41a0813fc498a9eb2779/spec12)

At the time of writing, also the specs that are present [on the website](http://ubjson.org). */
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
		deserialized array.
		
		`Nop` in a dictionary has no meaning and is always **skipped** (it is NOT
		(AFAICT) invalid to have a Nop element before a value in a dictionary in a
		non-optimized dictionary; the Nop is simply skipped). */
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
		Try and optimize the serialization of the containers. By default, uses the
		less expensive option, which is a JSON-like serialization. It is cheap to
		produce, but for containers whose values are all of the same types, will
		produce bigger serializations, and most importantly, is more expensive to
		deserialize.
		
		- Note: Our serializer will never produce the “first-level” optimization
		proposed in the specs (the count of the container is specified but not its
		type) because I don't think it has any advantages over the JSON-like
		representation. Happy to change my mind if somebody can give me good
		arguments in favor of this optimization :) */
		public static let enableContainerOptimization = WritingOptions(rawValue: 1 << 3)
		
		public init(rawValue v: Int) {
			rawValue = v
		}
		
	}
	
	public class func ubjsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any? {
		let simpleDataStream = DataReader(data: data)
		let ret = try ubjsonObject(with: simpleDataStream, options: opt)
		
		/* Check for no garbage at end of the data */
		let endOfData = try simpleDataStream.readDataToEnd()
		guard endOfData.first(where: { $0 != UBJSONElementType.nop.rawValue }) == nil else {throw UBJSONSerializationError.garbageAtEnd}
		
		return ret
	}
	
	public class func ubjsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> Any? {
		let simpleInputStream = InputStreamReader(stream: stream, bufferSize: 1024*1024, bufferSizeIncrement: 1024, readSizeLimit: nil)
		return try ubjsonObject(with: simpleInputStream, options: opt)
	}
	
	/* Note: We're using the StreamReader method instead of InputStream for
	 *       conveninence, but using InputStream directly would probably be
	 *       faster. Also we don't need all of the “clever” bits of StreamReader,
	 *       so one day we should migrate, or at least measure the performances
	 *       of both. */
	class func ubjsonObject(with streamReader: StreamReader, options opt: ReadingOptions = []) throws -> Any? {
		/* We assume Swift will continue to use the IEEE 754 spec for representing
		 * floats and doubles forever. Use of the spec validated in August 2017
		 * by @jckarter: https://twitter.com/jckarter/status/900073525905506304 */
		precondition(Int.max == Int64.max, "I currently need Int to be Int64")
		precondition(MemoryLayout<Float>.size == 4, "I currently need Float to be 32 bits")
		precondition(MemoryLayout<Double>.size == 8, "I currently need Double to be 64 bits")
		
		let elementType = try self.elementType(from: streamReader, allowNop: opt.contains(.returnNopElements))
		return try element(from: streamReader, type: elementType, options: opt)
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
		case var i as UInt8: size += try write(int: &i, to: stream, options: opt)
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
			size += try write(elementType: .highPrecisionNumber, toStream: stream)
			size += try write(stringNoMarker: strValue, to: stream, options: opt)
			
		case let c as Character:
			guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first, s.value >= 0 && s.value <= 127 else {
				throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: c)
			}
			
			var v: Int8 = Int8(s.value)
			size += try write(elementType: .char, toStream: stream)
			size += try stream.write(value: &v)
			
		case let s as String:
			size += try write(elementType: .string, toStream: stream)
			size += try write(stringNoMarker: s, to: stream, options: opt)
			
		case let a as [Any?]:
			size += try write(elementType: .arrayStart, toStream: stream)
			size += try write(arrayNoMarker: a, to: stream, options: opt)
			
		case let o as [String: Any?]:
			size += try write(elementType: .objectStart, toStream: stream)
			size += try write(objectNoMarker: o, to: stream, options: opt)
			
		case let unknown?:
			throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: unknown)
		}
		return size
	}
	
	/**
	Check a dictionary for UBJSON validity.
	
	You have an option to treat Nop as an invalid value, either if directly the
	value, or if it inside an array. Nop is always invalid inside a dictionary. */
	public class func isValidUBJSONObject(_ obj: Any?, treatNopAsInvalid: Bool = false, treatNopAsInvalidInArray: Bool = false) -> Bool {
		switch obj {
		case nil:                                                return true
		case _ as Nop:                                           return treatNopAsInvalid
		case _ as Bool, _ as Int, _ as Int8, _ as UInt8:         return true
		case _ as Int16, _ as Int32, _ as Int64, _ as Float:     return true
		case _ as Double, _ as HighPrecisionNumber, _ as String: return true
			
		case let c as Character:
			guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first else {return false}
			guard s.value >= 0 && s.value <= 127 else {return false}
			return true
			
		case let a as         [Any?]: return !a.contains(where: { !isValidUBJSONObject($0,       treatNopAsInvalid: treatNopAsInvalidInArray, treatNopAsInvalidInArray: treatNopAsInvalidInArray) })
		case let o as [String: Any?]: return !o.contains(where: { !isValidUBJSONObject($0.value, treatNopAsInvalid: true,                     treatNopAsInvalidInArray: treatNopAsInvalidInArray) })
			
		default:
			return false
		}
	}
	
	/**
	Check both given UBJSON for equality. Throws if the docs are not valid UBJSON
	docs! */
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
			
		case let val1 as UInt8:
			guard doc2 as? UInt8 == val1 else {
				if MemoryLayout<Int>.size == MemoryLayout<UInt8>.size, let val2 = doc2 as? Int, val1 == UInt8(val2) {return true}
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
				if MemoryLayout<Int>.size == MemoryLayout<UInt8>.size, let val2 = doc2 as? UInt8, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int16>.size, let val2 = doc2 as? Int16, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int32>.size, let val2 = doc2 as? Int32, val1 == Int(val2) {return true}
				if MemoryLayout<Int>.size == MemoryLayout<Int64>.size, let val2 = doc2 as? Int64, val1 == Int(val2) {return true}
				return false
			}
			
		case let val as Float:  guard doc2 as? Float  == val else {return false}
		case let val as Double: guard doc2 as? Double == val else {return false}
		case let str as String: guard doc2 as? String == str else {return false}
		case let val as Character: guard doc2 as? Character == val else {return false}
		case let val as HighPrecisionNumber: guard doc2 as? HighPrecisionNumber == val else {return false}
			
		case let subObj1 as [String: Any?]:
			guard let subObj2 = doc2 as? [String: Any?], subObj1.count == subObj2.count else {return false}
			for (subval1, subval2) in zip(subObj1, subObj2) {
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
	
	private class func elementType(from streamReader: StreamReader, allowNop: Bool) throws -> UBJSONElementType {
		var curElementType: UBJSONElementType
		repeat {
			let intType: UInt8 = try streamReader.readBigEndianInt()
			guard let e = UBJSONElementType(rawValue: intType) else {
				throw UBJSONSerializationError.invalidElementType(intType)
			}
			curElementType = e
		} while !allowNop && curElementType == .nop
		return curElementType
	}
	
	private class func highPrecisionNumber(from streamReader: StreamReader, options opt: ReadingOptions) throws -> HighPrecisionNumber {
		guard opt.contains(.allowHighPrecisionNumbers) else {throw UBJSONSerializationError.unexpectedHighPrecisionNumber}
		let str = try string(from: streamReader, options: opt, forcedMalformedError: .malformedHighPrecisionNumber)
		return try HighPrecisionNumber(unparsedValue: str)
	}
	
	private class func string(from streamReader: StreamReader, options opt: ReadingOptions, forcedMalformedError: UBJSONSerializationError? = nil, prereadSizeElement: Any?? = nil) throws -> String {
		guard let n = intValue(from: try prereadSizeElement ?? ubjsonObject(with: streamReader, options: opt.union(.returnNopElements))) else {
			throw forcedMalformedError ?? UBJSONSerializationError.malformedString
		}
		let strData = try streamReader.readData(size: n)
		guard let str = String(data: strData, encoding: .utf8) else {
			throw UBJSONSerializationError.invalidUTF8String(strData)
		}
		return str
	}
	
	private class func array(from streamReader: StreamReader, options opt: ReadingOptions) throws -> [Any?] {
		var res = [Any?]()
		let subParseOptWithNop = opt.union(.returnNopElements)
		
		var declaredObjectCount: Int?
		var curObj: Any?? = try ubjsonObject(with: streamReader, options: subParseOptWithNop)
		switch curObj {
		case InternalUBJSONElement.containerType(let t)??:
			guard let countType = try ubjsonObject(with: streamReader, options: subParseOptWithNop) as? InternalUBJSONElement, case .containerCount(let c) = countType else {
				throw UBJSONSerializationError.malformedArray
			}
			switch t {
			case .null:    return [Any?](repeating: nil,   count: c)
			case .`true`:  return [Bool](repeating: true,  count: c)
			case .`false`: return [Bool](repeating: false, count: c)
				
			case .int8Bits:    let ret:   [Int8] = try streamReader.readArrayOfType(count: c); return !opt.contains(.keepIntPrecision) ? ret.map{ Int($0) } : ret
			case .uint8Bits:   let ret:  [UInt8] = try streamReader.readArrayOfType(count: c); return !opt.contains(.keepIntPrecision) ? ret.map{ Int($0) } : ret
			case .int16Bits:   let ret:  [Int16] = try (0..<c).map{ i in try streamReader.readBigEndianInt() }; return !opt.contains(.keepIntPrecision) ? ret.map{ Int($0) } : ret
			case .int32Bits:   let ret:  [Int32] = try (0..<c).map{ i in try streamReader.readBigEndianInt() }; return !opt.contains(.keepIntPrecision) ? ret.map{ Int($0) } : ret
			case .int64Bits:   let ret:  [Int64] = try (0..<c).map{ i in try streamReader.readBigEndianInt() }; return !opt.contains(.keepIntPrecision) ? ret.map{ Int($0) } : ret
			case .float32Bits: let ret:  [Float] = try (0..<c).map{ i in try streamReader.readBigEndianFloat() };  return ret
			case .float64Bits: let ret: [Double] = try (0..<c).map{ i in try streamReader.readBigEndianDouble() }; return ret
				
			case .highPrecisionNumber:
				return try (0..<c).map{ _ in try highPrecisionNumber(from: streamReader, options: opt) }
				
			case .char:
				let charsAsInts: [Int8] = try streamReader.readArrayOfType(count: c)
				return try charsAsInts.map{
					guard $0 >= 0 && $0 <= 127, let s = Unicode.Scalar(Int($0)) else {throw UBJSONSerializationError.invalidChar($0)}
					return Character(s)
				}
				
			case .string:
				return try (0..<c).map{ _ in try string(from: streamReader, options: opt) }
				
			case .arrayStart:
				return try (0..<c).map{ _ in try array(from: streamReader, options: opt) }
				
			case .objectStart:
				return try (0..<c).map{ _ in try object(from: streamReader, options: opt) }
				
			case .nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount:
				fatalError()
			}
			
		case InternalUBJSONElement.containerCount(let c)??:
			declaredObjectCount = c
			curObj = nil
			
		default: (/*nop*/)
		}
		
		var objectCount = 0
		while !isEndOfContainer(currentObjectCount: objectCount, declaredObjectCount: declaredObjectCount, currentObject: curObj, containerEnd: .arrayEnd) {
			let v = try curObj ?? ubjsonObject(with: streamReader, options: subParseOptWithNop)
			switch v {
			case .some(_ as InternalUBJSONElement):
				/* Always an error as the arrayEnd case is detected earlier in
				 * the isEndOfContainer method */
				throw UBJSONSerializationError.malformedArray
				
			case .some(_ as Nop):
				if opt.contains(.keepNopElementsInArrays) {
					res.append(Nop.sharedNop)
				}
				
			default:
				res.append(v)
				objectCount += 1
			}
			
			/* Prepare end array detection */
			curObj = (declaredObjectCount == nil ? .some(try ubjsonObject(with: streamReader, options: subParseOptWithNop)) : nil)
		}
		return res
	}
	
	private class func object(from streamReader: StreamReader, options opt: ReadingOptions) throws -> [String: Any?] {
		var res = [String: Any?]()
		let subParseOptNoNop = opt.subtracting(.returnNopElements)
		let subParseOptWithNop = opt.union(.returnNopElements)
		
		var curObj: Any??
		var declaredObjectCount: Int?
		let type = try elementType(from: streamReader, allowNop: true)
		switch type {
		case .internalContainerType:
			/* The object is optimized with a type and a count. */
			let containerType = try element(from: streamReader, type: type, options: subParseOptWithNop) as! InternalUBJSONElement
			guard
				case .containerType(let t) = containerType,
				let containerCount = try ubjsonObject(with: streamReader, options: subParseOptWithNop) as? InternalUBJSONElement,
				case .containerCount(let c) = containerCount
			else {
				throw UBJSONSerializationError.malformedObject
			}
			
			var ret = [String: Any?]()
			for _ in 0..<c {
				let k = try string(from: streamReader, options: subParseOptNoNop, forcedMalformedError: .malformedObject)
				let v = try element(from: streamReader, type: t, options: subParseOptNoNop)
				ret[k] = v
			}
			return ret
			
		case .internalContainerCount:
			/* Object optimized with a count only. */
			let containerCount = try element(from: streamReader, type: type, options: subParseOptWithNop) as! InternalUBJSONElement
			guard case .containerCount(let c) = containerCount else {throw UBJSONSerializationError.internalError}
			declaredObjectCount = c
			
		default:
			/* If the object is unoptimized, we must read the first object so we
			 * can determine whether the end of the object has been reached. Also,
			 * if we don't read the element, we will probably have parsed half an
			 * element (type is parsed, but not the value). */
			curObj = try element(from: streamReader, type: type, options: subParseOptWithNop)
		}
		
		var objectCount = 0
		while !isEndOfContainer(currentObjectCount: objectCount, declaredObjectCount: declaredObjectCount, currentObject: curObj, containerEnd: .objectEnd) {
			let key = try string(from: streamReader, options: subParseOptWithNop, forcedMalformedError: .malformedObject, prereadSizeElement: curObj)
			
			let value = try ubjsonObject(with: streamReader, options: subParseOptNoNop)
			switch value {
			case .some(_ as InternalUBJSONElement):
				/* Always an error as the objectEnd case is detected earlier in
				 * the isEndOfContainer method */
				throw UBJSONSerializationError.malformedObject
				
			default:
				assert(value == nil || !(value! is Nop))
				res[key] = value
				objectCount += 1
			}
			
			/* Prepare end object detection */
			curObj = (declaredObjectCount == nil ? .some(try ubjsonObject(with: streamReader, options: subParseOptNoNop)) : nil)
		}
		return res
	}
	
	private class func element(from streamReader: StreamReader, type elementType: UBJSONElementType, options opt: ReadingOptions) throws -> Any? {
		switch elementType {
		case .nop:
			assert(opt.contains(.returnNopElements))
			return Nop()
			
		case .null:    return nil
		case .`true`:  return true
		case .`false`: return false
			
		case .int8Bits:    let ret:   Int8 = try streamReader.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .uint8Bits:   let ret:  UInt8 = try streamReader.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int16Bits:   let ret:  Int16 = try streamReader.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int32Bits:   let ret:  Int32 = try streamReader.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .int64Bits:   let ret:  Int64 = try streamReader.readBigEndianInt(); return opt.contains(.keepIntPrecision) ? ret : Int(ret)
		case .float32Bits: let ret:  Float = try streamReader.readBigEndianFloat();  return ret
		case .float64Bits: let ret: Double = try streamReader.readBigEndianDouble(); return ret
			
		case .highPrecisionNumber:
			return try highPrecisionNumber(from: streamReader, options: opt)
			
		case .char:
			let ci: Int8 = try streamReader.readBigEndianInt()
			guard ci >= 0 && ci <= 127, let s = Unicode.Scalar(Int(ci)) else {throw UBJSONSerializationError.invalidChar(ci)}
			return Character(s)
			
		case .string:
			return try string(from: streamReader, options: opt)
			
		case .arrayStart:
			return try array(from: streamReader, options: opt)
			
		case .objectStart:
			return try object(from: streamReader, options: opt)
			
		case .arrayEnd:  return InternalUBJSONElement.arrayEnd
		case .objectEnd: return InternalUBJSONElement.objectEnd
			
		case .internalContainerType:
			let invalidTypes: Set<UBJSONElementType> = [.nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount]
			let intContainerType: UInt8 = try streamReader.readBigEndianInt()
			guard let containerType = UBJSONElementType(rawValue: intContainerType), !invalidTypes.contains(containerType) else {
				throw UBJSONSerializationError.invalidContainerType(intContainerType)
			}
			return InternalUBJSONElement.containerType(containerType)
			
		case .internalContainerCount:
			guard let n = intValue(from: try ubjsonObject(with: streamReader, options: opt.union(.returnNopElements))) else {
				throw UBJSONSerializationError.malformedContainerCount
			}
			return InternalUBJSONElement.containerCount(n)
		}
	}
	
	/**
	Determine whether the end of the container has been reached with a given set
	of parameter.
	
	If the declared object count is nil (was not declared in the container), the
	current object must not be nil. (Can be .some(nil), though!) */
	private class func isEndOfContainer(currentObjectCount: Int, declaredObjectCount: Int?, currentObject: Any??, containerEnd: InternalUBJSONElement) -> Bool {
		if let declaredObjectCount = declaredObjectCount {
			assert(currentObjectCount <= declaredObjectCount)
			return currentObjectCount == declaredObjectCount
		} else {
			return currentObject! == containerEnd
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
	
	private class func write(elementType: UBJSONElementType, toStream stream: OutputStream) throws -> Int {
		var t = elementType.rawValue
		return try stream.write(value: &t)
	}
	
	private class func write(stringNoMarker s: String, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		let data = Data(s.utf8)
		size += try writeUBJSONObject(data.count, to: stream, options: opt)
		try data.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
		return size
	}
	
	private class func write(int i: inout Int8, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		size += try write(elementType: .int8Bits, toStream: stream)
		size += try stream.write(value: &i)
		return size
	}
	
	private class func write(int i: inout UInt8, to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		size += try write(elementType: .uint8Bits, toStream: stream)
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
		
		if      i >=  Int8.min && i <=  Int8.max {var i =  Int8(i); return try write(int: &i, to: stream, options: opt)}
		else if i >= UInt8.min && i <= UInt8.max {var i = UInt8(i); return try write(int: &i, to: stream, options: opt)}
		else                                     {                  return try write(int: &i, to: stream, options: optNoOptim)}
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
		else if i >= UInt8.min && i <= UInt8.max {var i = UInt8(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else if i >= Int16.min && i <= Int16.max {var i = Int16(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else if i >= Int32.min && i <= Int32.max {var i = Int32(i); return try write(int: &i, to: stream, options: optNoOptim)}
		else                                     {var i = Int64(i); return try write(int: &i, to: stream, options: optNoOptim)}
	}
	
	private class func write(arrayNoMarker a: [Any?], to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		
		let optNoSkipNop = opt.subtracting(.skipNopElementsInArrays)
		let a = !opt.contains(.skipNopElementsInArrays) ? a : dropNopRecursively(element: a) as! [Any?]
		
		if opt.contains(.enableContainerOptimization), let t = typeForOptimizedContainer(values: a) {
			/* Container info */
			size += try write(elementType: .internalContainerType, toStream: stream)
			size += try write(elementType: t, toStream: stream)
			size += try write(elementType: .internalContainerCount, toStream: stream)
			size += try write(int: a.count, to: stream, options: opt)
			
			/* Container values */
			switch t {
			case .nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount: fatalError("Internal logic error")
				
			case .null, .`true`, .`false`: (/*nop*/)
				
			case .int8Bits:    try a.map{  int8(from: $0!) }.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
			case .uint8Bits:   try a.map{ uint8(from: $0!) }.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
			case .int16Bits:   try a.map{ int16(from: $0!) }.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
			case .int32Bits:   try a.map{ int32(from: $0!) }.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
			case .int64Bits:   try a.map{ int64(from: $0!) }.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
			case .float32Bits: try (a as! [Float]).withUnsafeBytes{  ptr in size += try stream.write(dataPtr: ptr) }
			case .float64Bits: try (a as! [Double]).withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
				
			case .highPrecisionNumber:
				try (a as! [HighPrecisionNumber]).forEach{ h in
					let strValue = opt.contains(.normalizeHighPrecisionNumbers) ? h.normalizedStringValue : h.stringValue
					size += try write(stringNoMarker: strValue, to: stream, options: opt)
				}
				
			case .char:
				let charsAsInts = try (a as! [Character]).map{ c -> Int8 in
					guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first, s.value >= 0 && s.value <= 127 else {
						throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: c)
					}
					return Int8(s.value)
				}
				try charsAsInts.withUnsafeBytes{ ptr in size += try stream.write(dataPtr: ptr) }
				
			case .string:
				try (a as! [String]).forEach{ s in size += try write(stringNoMarker: s, to: stream, options: opt) }
				
			case .arrayStart:
				try (a as! [[Any?]]).forEach{ s in size += try write(arrayNoMarker: s, to: stream, options: optNoSkipNop) }
				
			case .objectStart:
				try (a as! [[String: Any?]]).forEach{ s in size += try write(objectNoMarker: s, to: stream, options: optNoSkipNop) }
			}
		} else {
			/* Writing array with standard (JSON-like) notation */
			for e in a {size += try writeUBJSONObject(e, to: stream, options: opt)}
			size += try write(elementType: .arrayEnd, toStream: stream)
		}
		return size
	}
	
	private class func write(objectNoMarker o: [String: Any?], to stream: OutputStream, options opt: WritingOptions) throws -> Int {
		var size = 0
		
		if opt.contains(.enableContainerOptimization), let t = typeForOptimizedContainer(values: o.values) {
			/* Container info */
			size += try write(elementType: .internalContainerType, toStream: stream)
			size += try write(elementType: t, toStream: stream)
			size += try write(elementType: .internalContainerCount, toStream: stream)
			size += try write(int: o.count, to: stream, options: opt)
			
			/* Container values */
			let writer: (_ object: Any?) throws -> Int
			switch t {
			case .nop, .arrayEnd, .objectEnd, .internalContainerType, .internalContainerCount: fatalError("Internal logic error")
				
			case .null, .`true`, .`false`: writer = { _ in return 0 }
				
			case .int8Bits:    writer = { o in var v =  int8(from: o!);  return try stream.write(value: &v) }
			case .uint8Bits:   writer = { o in var v = uint8(from: o!);  return try stream.write(value: &v) }
			case .int16Bits:   writer = { o in var v = int16(from: o!);  return try stream.write(value: &v) }
			case .int32Bits:   writer = { o in var v = int32(from: o!);  return try stream.write(value: &v) }
			case .int64Bits:   writer = { o in var v = int64(from: o!);  return try stream.write(value: &v) }
			case .float32Bits: writer = { o in var v = (o as! Float);  return try stream.write(value: &v) }
			case .float64Bits: writer = { o in var v = (o as! Double); return try stream.write(value: &v) }
				
			case .highPrecisionNumber:
				writer = { o in
					let h = (o as! HighPrecisionNumber)
					let strValue = opt.contains(.normalizeHighPrecisionNumbers) ? h.normalizedStringValue : h.stringValue
					return try write(stringNoMarker: strValue, to: stream, options: opt)
				}
				
			case .char:
				writer = { o in
					let c = (o as! Character)
					guard c.unicodeScalars.count == 1, let s = c.unicodeScalars.first, s.value >= 0 && s.value <= 127 else {
						throw UBJSONSerializationError.invalidUBJSONObject(invalidElement: c)
					}
					var v = Int8(s.value)
					return try stream.write(value: &v)
				}
				
			case .string:
				writer = { o in try write(stringNoMarker: o as! String, to: stream, options: opt) }
				
			case .arrayStart:
				writer = { o in try write(arrayNoMarker: o as! [Any?], to: stream, options: opt) }
				
			case .objectStart:
				writer = { o in try write(objectNoMarker: o as! [String: Any?], to: stream, options: opt) }
			}
			for (k, v) in o {
				size += try write(stringNoMarker: k, to: stream, options: opt)
				size += try writer(v)
			}
		} else {
			/* Writing dictionary with standard (JSON-like) notation */
			for (k, v) in o {
				guard !(v is Nop) else {throw UBJSONSerializationError.dictionaryContainsNop}
				size += try write(stringNoMarker: k, to: stream, options: opt)
				size += try writeUBJSONObject(v, to: stream, options: opt)
			}
			size += try write(elementType: .objectEnd, toStream: stream)
		}
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
	
	private class func typeForOptimizedContainer<S : Collection>(values: S) -> UBJSONElementType? {
		guard values.count >= 5 else {return nil} /* Under 5 elements, the optimized container is actually bigger or the same size as the normal one */
		
		var minInt = Int64.max
		var maxInt = Int64.min
		var latestType: UBJSONElementType?
		for v in values {
			let newType: UBJSONElementType
			switch v {
			case _ as Nop: return nil
				
			case nil:                    newType = .null
			case let b as Bool where  b: newType = .`true`
			case let b as Bool where !b: newType = .`false`
				
			case let i as   Int: newType = .int64Bits; minInt = min(minInt, Int64(i)); maxInt = max(maxInt, Int64(i))
			case let i as  Int8: newType = .int64Bits; minInt = min(minInt, Int64(i)); maxInt = max(maxInt, Int64(i))
			case let i as UInt8: newType = .int64Bits; minInt = min(minInt, Int64(i)); maxInt = max(maxInt, Int64(i))
			case let i as Int16: newType = .int64Bits; minInt = min(minInt, Int64(i)); maxInt = max(maxInt, Int64(i))
			case let i as Int32: newType = .int64Bits; minInt = min(minInt, Int64(i)); maxInt = max(maxInt, Int64(i))
			case let i as Int64: newType = .int64Bits; minInt = min(minInt,       i ); maxInt = max(maxInt,       i )
				
			case _ as Float:  newType = .float32Bits
			case _ as Double: newType = .float64Bits
				
			case _ as HighPrecisionNumber: newType = .highPrecisionNumber
			case _ as Character:           newType = .char
			case _ as String:              newType = .string
				
			case _ as [Any?]:         newType = .arrayStart
			case _ as [String: Any?]: newType = .objectStart
				
			default: return nil
			}
			
			guard latestType == newType || latestType == nil else {return nil}
			latestType = newType
		}
		
		if latestType! == .int64Bits {
			/* Let's find the actual int type we'll use */
			if maxInt <=  Int8.max && minInt >=  Int8.min {return .int8Bits}
			if maxInt <= UInt8.max && minInt >= UInt8.min {return .uint8Bits}
			if maxInt <= Int16.max && minInt >= Int16.min {return .int16Bits}
			if maxInt <= Int32.max && minInt >= Int32.min {return .int32Bits}
			return .int64Bits
		}
		
		return latestType!
	}
	
	private class func int8(from o: Any) -> Int8 {
		switch o {
		case let i as Int8:  return i
		case let i as UInt8: return Int8(i)
		case let i as Int16: return Int8(i)
		case let i as Int32: return Int8(i)
		case let i as Int64: return Int8(i)
		case let i as Int:   return Int8(i)
		default: fatalError("Invalid object to convert to int8: \(o)")
		}
	}
	
	private class func uint8(from o: Any) -> UInt8 {
		switch o {
		case let i as Int8:  return UInt8(i)
		case let i as UInt8: return i
		case let i as Int16: return UInt8(i)
		case let i as Int32: return UInt8(i)
		case let i as Int64: return UInt8(i)
		case let i as Int:   return UInt8(i)
		default: fatalError("Invalid object to convert to uint8: \(o)")
		}
	}
	
	private class func int16(from o: Any) -> Int16 {
		switch o {
		case let i as Int8:  return Int16(i)
		case let i as UInt8: return Int16(i)
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
		case let i as UInt8: return Int32(i)
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
		case let i as UInt8: return Int64(i)
		case let i as Int16: return Int64(i)
		case let i as Int32: return Int64(i)
		case let i as Int64: return i
		case let i as Int:   return Int64(i)
		default: fatalError("Invalid object to convert to int64: \(o)")
		}
	}
	
}



private extension StreamReader {
	
	func readArrayOfType<Type>(count: Int) throws -> [Type] {
		assert(MemoryLayout<Type>.stride == MemoryLayout<Type>.size)
		/* Adapted (and upgraded) from https://stackoverflow.com/a/24516400 */
		return try readData(size: count * MemoryLayout<Type>.size, { bytes in
			let bound = bytes.bindMemory(to: Type.self)
			return Array(bound)
		})
	}
	
}
