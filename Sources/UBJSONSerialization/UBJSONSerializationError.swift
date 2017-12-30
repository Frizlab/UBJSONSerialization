/*
 * UBJSONSerializationError.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 8/22/17.
 */

import Foundation



/** The UBJSON Serialization errors enum. */
public enum UBJSONSerializationError : Error {
	
	/** An invalid element was found. The element is given in argument to this
	enum case. */
	case invalidElementType(UInt8)
	
	/** An invalid high-preicision number was found. */
	case invalidHighPrecisionNumber(String)
	
}
