/*
 * UBJSONSerializationError.swift
 * UBJSONSerialization
 *
 * Created by François Lamboley on 8/22/17.
 */

import Foundation



/** The UBJSON Serialization errors enum. */
public enum UBJSONSerializationError : Error {
	
	/** Only when decoding from Data (as opposed to decoding from a stream), if
	there are non-ignorable data after an element has been deserialized, this
	error will be thrown. */
	case garbageAtEnd
	
	/** An invalid element was found. The element is given in argument to this
	enum case. */
	case invalidElementType(UInt8)
	/** A high precision number element was found but the option to support them
	was not set when parsing was called. */
	case unexpectedHighPrecisionNumber
	
	case invalidUTF8String(Data)
	/** A char must be between 0 and 127 (both inclusive). */
	case invalidChar(Int8)
	case invalidContainerType(UInt8)
	
	case malformedHighPrecisionNumber
	case malformedString
	case malformedContainerCount
	case malformedArray
	case malformedObject
	
	/** An invalid high-preicision number string was found. */
	case invalidHighPrecisionNumber(String)
	
	/** An error occurred writing to the stream. */
	case cannotWriteToStream(streamError: Error?)
	
	/** An invalid UBJSON object was given to be serialized. The invalid element
	is passed in argument to this error. */
	case invalidUBJSONObject(invalidElement: Any)
	
	/* Spec 8 error */
	case sizedArrayContainsNop
	case dictionaryContainsNop /* Both spec 8 and 12 */
	
	case internalError
	
}
