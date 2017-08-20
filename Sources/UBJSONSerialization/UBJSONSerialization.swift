/*
 * UBJSONSerialization.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 1/17/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import SimpleStream



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
	
	public class func ubjsonObject(with data: Data, options opt: ReadingOptions = []) throws -> Any? {
		let simpleDataStream = SimpleDataStream(data: data)
		return try ubjsonObject(with: simpleDataStream, options: opt)
	}
	
	public class func ubjsonObject(with stream: InputStream, options opt: ReadingOptions = []) throws -> Any? {
		let simpleInputStream = SimpleInputStream(stream: stream, bufferSize: 1024*1024, streamReadSizeLimit: nil)
		return try ubjsonObject(with: simpleInputStream, options: opt)
	}
	
	class func ubjsonObject(with bufferStream: SimpleStream, options opt: ReadingOptions = []) throws -> Any? {
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
	
}
