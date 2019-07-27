# UBJSONSerialization

UBJSON Serialization in native Swift 4.2

## Installation & Compatibility
The recommended (and only tested) way to install and use UBJSONSerialization is
via `SwiftPM`, using at least Swift 4.2.

The content of your `Package.swift` should be something resembling:
```swift
import PackageDescription

let package = Package(
	name: "myawesomeproject",
	dependencies: [.package(url: "https://github.com/Frizlab/UBJSONSerialization.git", from: "1.0.1")],
	targets: [.target(name: "myawesomeproject", dependencies: ["UBJSONSerialization"])]
)
```

## Usage
`UBJSONSerialization` has the same basic interface than `JSONSerialization`.

Example of use:
```swift
let myFirstUBJSONDoc = ["key": "value"]
let serializedUBJSONDoc = try UBJSONSerialization.data(withUBJSONObject: myFirstUBJSONDoc, options: [])
let unserializedUBJSONDoc = try UBJSONSerialization.ubjsonObject(with: serializedUBJSONDoc, options: [])
print(myFirstUBJSONDoc == unserializedUBJSONDoc as! [String: String])
```

Serializing/deserializing to/from a stream is also supported.
**Important**: Unlike `JSONSerialization`, when a full valid object has been parsed
from a [SimpleStream](https://github.com/Frizlab/SimpleStream), you can unserialized
another object from the same stream. This is useful to parse a multiple separated
documents coming in a single stream.

Finally, a method lets you know if a given dictionary can be serialized as an
UBJSON document.

## Alternatives
I am not aware of any other implementation of UBJSON serialization/deserialization at
the moment in Swift.

## Reference
I used the UBJSON specification from http://ubjson.org

## To Do
- [ ] Verify support for decoding multiple UBJSON docs in a single stream;
- [ ] Support for streaming (receiving/sending data live);
- [ ] At some point in the future, but maybe in a separate project, add support for
Swift’s Encoder protocol.
- [ ] Swift NIO support?

I’ll work seriously on the project if it gains enough attention. Feel free to
open issues, I’ll do my best to answer.

Pull requests are welcome 😉

## License
MIT (see License.txt file)
