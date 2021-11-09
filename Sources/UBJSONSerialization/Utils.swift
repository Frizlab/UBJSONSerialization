/*
 * Utils.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 2019/6/26.
 */

import Foundation

import StreamReader



extension OutputStream {
	
	func write(dataPtr: UnsafeRawBufferPointer) throws -> Int {
		guard dataPtr.count > 0 else {return 0}
		
		let bound = dataPtr.bindMemory(to: UInt8.self)
		let writtenSize = write(bound.baseAddress!, maxLength: dataPtr.count)
		guard writtenSize == dataPtr.count else {throw Err.cannotWriteToStream(streamError: streamError)}
		return dataPtr.count
	}
	
	func write(value: inout Int) throws -> Int {
		let size = MemoryLayout<Int>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<Int>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Int8) throws -> Int {
		let size = MemoryLayout<Int8>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<Int8>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout UInt8) throws -> Int {
		let size = MemoryLayout<UInt8>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<UInt8>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Int16) throws -> Int {
		let size = MemoryLayout<Int16>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<Int16>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Int32) throws -> Int {
		let size = MemoryLayout<Int32>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<Int32>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Int64) throws -> Int {
		let size = MemoryLayout<Int64>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<Int64>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Float) throws -> Int {
		let size = MemoryLayout<Float>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bitPattern.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<UInt32>(start: pointer, count: 1)))
		})
	}
	
	func write(value: inout Double) throws -> Int {
		let size = MemoryLayout<Double>.size
		guard size > 0 else {return 0} /* Highly unlikely (understand completely impossible) */
		
		var bigEndian = value.bitPattern.bigEndian
		return try withUnsafePointer(to: &bigEndian, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<UInt64>(start: pointer, count: 1)))
		})
	}
	
	func write<T>(value: inout T) throws -> Int {
		let size = MemoryLayout<T>.size
		guard size > 0 else {return 0} /* Void size is 0 */
		
		return try withUnsafePointer(to: &value, { pointer -> Int in
			return try write(dataPtr: UnsafeRawBufferPointer(UnsafeBufferPointer<T>(start: pointer, count: 1)))
		})
	}
	
}


extension StreamReader {
	
	func readBigEndianInt() throws -> Int {
		let i: Int = try readType()
		return Int(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> Int8 {
		let i: Int8 = try readType()
		return Int8(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> UInt8 {
		let i: UInt8 = try readType()
		return UInt8(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> Int16 {
		let i: Int16 = try readType()
		return Int16(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> Int32 {
		let i: Int32 = try readType()
		return Int32(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> UInt32 {
		let i: UInt32 = try readType()
		return UInt32(bigEndian: i)
	}
	
	func readBigEndianInt() throws -> Int64 {
		let i: Int64 = try readType()
		return Int64(bigEndian: i)
	}
	
	func readBigEndianFloat() throws -> Float {
		let v: Float = try readType()
		let bitPattern = UInt32(bigEndian: v.bitPattern)
		return Float(bitPattern: bitPattern)
	}
	
	func readBigEndianDouble() throws -> Double {
		let v: Double = try readType()
		let bitPattern = UInt64(bigEndian: v.bitPattern)
		return Double(bitPattern: bitPattern)
	}
	
}
