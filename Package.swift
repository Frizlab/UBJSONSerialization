// swift-tools-version:5.1
import PackageDescription


let package = Package(
	name: "UBJSONSerialization",
	products: [
		.library(name: "UBJSONSerialization", targets: ["UBJSONSerialization"])
	],
	dependencies: [
		.package(url: "https://github.com/Frizlab/stream-reader.git", from: "3.0.0")
	],
	targets: [
		.target(name: "UBJSONSerialization", dependencies: [.product(name: "StreamReader", package: "stream-reader")]),
		.testTarget(name: "UBJSONSerializationTests", dependencies: ["UBJSONSerialization"])
	]
)
