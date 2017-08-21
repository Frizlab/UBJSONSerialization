/*
 * UBJSONSerialization.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import SimpleStream



/** To represent the No-Op element of UBJSON. */
public struct Nop {
}


final public class UBJSONSerialization {
	
	public struct ReadingOptions : OptionSet {
		
		public let rawValue: Int
		/* Empty. We just create the enum in case we want to add something to it later. */
		
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
	
	/** The UBJSON Serialization errors enum. */
	public enum UBJSONSerializationError : Error {
		/** An invalid element was found. The element is given in argument to this
		enum case. */
		case invalidElementType(UInt8)
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
	class func ubjsonObject(with bufferStream: SimpleStream, options opt: ReadingOptions = []) throws -> Any? {
		let intType: UInt8 = try bufferStream.readType()
		guard let elementType = UBJSONElementType(rawValue: intType) else {
			throw UBJSONSerializationError.invalidElementType(intType)
		}
		
		switch elementType {
		case .null:    return nil
		case .nop:     return Nop()
		case .`true`:  return true
		case .`false`: return false
			
		case .int8Bits: ()
		case .uint8Bits: ()
		case .int16Bits: ()
		case .int32Bits: ()
		case .int64Bits: ()
		case .float32Bits: ()
		case .float64Bits: ()
		case .highPrecisionNumber: ()
		case .char: ()
		case .string: ()
		case .arrayStart: ()
		case .objectStart: ()
		case .arrayEnd: ()
		case .objectEnd: ()
		}
		throw NSError(domain: "todo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not Implemented"])
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
		
	}
	
}
