/*
 * Nop.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 2019/6/24.
 */

import Foundation



/**
 To represent the `No-Op` element of UBJSON.
 This should usually **NOT** be used.
 
 This element is invalid as a value of a dictionary.
 
 It should be used pretty much only when we have proper streaming support to send ``Nop`` values in a stream to keep it alive. */
public struct Nop : Equatable {
	
	public static let sharedNop = Nop()
	
	public static func ==(lhs: Nop,  rhs: Nop) -> Bool {return true}
	public static func ==(lhs: Any?, rhs: Nop) -> Bool {return lhs is Nop}
	
}
